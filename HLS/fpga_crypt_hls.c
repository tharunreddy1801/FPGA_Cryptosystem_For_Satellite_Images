/**
 * @file image_crypto.c
 * @brief 4D Chen Chaotic Image Cryptosystem for Zedboard ARM (Xilinx Vitis)
 *
 * Pipeline:
 *   SHA-256(image) → Chen4D RK4 → X/Y/Z/W keys
 *   Encrypt: XOR(X) → FisherYates(Y) → RNA_Encode(Z) → XOR(W)
 *   Decrypt: XOR(W) → RNA_Decode(Z) → Rev_FisherYates(Y) → XOR(X)
 *
 * UART Protocol (sent to host PC):
 *   Each image block: 4-byte magic + 4-byte size + pixel data
 *   Magic bytes identify stage:
 *     0xAA 0x01 → Original image
 *     0xAA 0x02 → After Stage 1 (XOR whitened)
 *     0xAA 0x03 → After Stage 2 (Fisher-Yates shuffled)
 *     0xAA 0x04 → After Stage 3 (RNA encoded)
 *     0xAA 0x05 → Final encrypted image
 *     0xAA 0x06 → Decrypted Stage 1 (reverse XOR W)
 *     0xAA 0x07 → Decrypted Stage 2 (RNA decoded)
 *     0xAA 0x08 → Decrypted Stage 3 (reverse FY)
 *     0xAA 0x09 → Final decrypted image
 *     0xAA 0x0A → Metrics packet (NPCR/UACI as ASCII)
 *
 * @note Compile in Xilinx Vitis as a standalone bare-metal application.
 *       Ensure TestImage.h provides:
 *         extern const uint32_t imageData[IMG_HEIGHT * IMG_WIDTH];
 *         (packed 0x00RRGGBB or grayscale as 0x00VVVVVV)
 *       and defines IMG_WIDTH, IMG_HEIGHT.
 *       This code works for grayscale (1 byte/pixel) images.
 *       If your TestImage.h is RGB, set USE_RGB 1 below.
 */

/*===========================================================================
 * INCLUDES
 *===========================================================================*/
#include "xparameters.h"
#include "xuartps.h"
#include "xtime_l.h"
#include "xil_cache.h"
#include "sleep.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include "TestImage.h"

/*===========================================================================
 * CONFIGURATION — edit these to match your TestImage.h
 *===========================================================================*/
/* Set to 1 if your image is RGB (3 bytes/pixel), 0 for grayscale */
#define USE_RGB          0

/* UART baud rate */
#define BAUD_RATE        115200

/* UART burst size for transmission */
#define UART_BURST       256

/* Chen4D parameters (must match MATLAB) */
#define ALPHA            35.0
#define GAMMA_P          28.0
#define EPSILON          12.0
#define BETA_P           3.0
#define LAMBDA_P         0.5
#define H_STEP           0.01
#define N_TRANSIENT      20000   /* transient iterations to discard */

/* Initial condition offsets (must match MATLAB x0,y0,z0,w0) */
#define X0_OFFSET        0.0
#define Y0_OFFSET        0.0
#define Z0_OFFSET        8.0
#define W0_OFFSET        6.0

/* Fisher-Yates block size (must match MATLAB) */
#define BLOCK_SIZE       16

/*===========================================================================
 * DERIVED CONSTANTS
 *===========================================================================*/
#if USE_RGB
#define BYTES_PER_PIXEL  3
#else
#define BYTES_PER_PIXEL  1
#endif

#define IMG_WIDTH        256
#define IMG_HEIGHT       256
#define IMG_PIXELS       (IMG_WIDTH * IMG_HEIGHT)
#define IMG_BYTES        (IMG_PIXELS * BYTES_PER_PIXEL)

/* For Fisher-Yates: trim to block-aligned size */
#define FY_H             ((IMG_HEIGHT / BLOCK_SIZE) * BLOCK_SIZE)
#define FY_W             ((IMG_WIDTH  / BLOCK_SIZE) * BLOCK_SIZE)
#define FY_PIXELS        (FY_H * FY_W)

/*===========================================================================
 * UART MAGIC BYTES
 *===========================================================================*/
#define MAGIC_BYTE       0xAA
#define IMG_ORIGINAL     0x01
#define IMG_STAGE1       0x02
#define IMG_STAGE2       0x03
#define IMG_STAGE3       0x04
#define IMG_ENCRYPTED    0x05
#define IMG_DEC_STAGE1   0x06
#define IMG_DEC_STAGE2   0x07
#define IMG_DEC_STAGE3   0x08
#define IMG_DECRYPTED    0x09
#define PKT_METRICS      0x0A

/*===========================================================================
 * SHA-256 IMPLEMENTATION (FIPS 180-4)
 *===========================================================================*/
typedef struct {
    uint8_t  data[64];
    uint32_t datalen;
    uint64_t bitlen;
    uint32_t state[8];
} SHA256_CTX;

static const uint32_t sha256_k[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,
    0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,
    0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,
    0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,
    0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,
    0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,
    0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,
    0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,
    0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

#define ROTRIGHT(a,b) (((a) >> (b)) | ((a) << (32-(b))))
#define CH(x,y,z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2)  ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6)  ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x)(ROTRIGHT(x,7)  ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x)(ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

static void sha256_transform(SHA256_CTX *ctx, const uint8_t data[])
{
    uint32_t a,b,c,d,e,f,g,h,i,j,t1,t2,m[64];

    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = ((uint32_t)data[j] << 24) | ((uint32_t)data[j+1] << 16) |
               ((uint32_t)data[j+2] << 8) | (uint32_t)data[j+3];
    for (; i < 64; ++i)
        m[i] = SIG1(m[i-2]) + m[i-7] + SIG0(m[i-15]) + m[i-16];

    a=ctx->state[0]; b=ctx->state[1]; c=ctx->state[2]; d=ctx->state[3];
    e=ctx->state[4]; f=ctx->state[5]; g=ctx->state[6]; h=ctx->state[7];

    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e,f,g) + sha256_k[i] + m[i];
        t2 = EP0(a) + MAJ(a,b,c);
        h=g; g=f; f=e; e=d+t1;
        d=c; c=b; b=a; a=t1+t2;
    }

    ctx->state[0]+=a; ctx->state[1]+=b; ctx->state[2]+=c; ctx->state[3]+=d;
    ctx->state[4]+=e; ctx->state[5]+=f; ctx->state[6]+=g; ctx->state[7]+=h;
}

static void sha256_init(SHA256_CTX *ctx)
{
    ctx->datalen = 0; ctx->bitlen = 0;
    ctx->state[0]=0x6a09e667; ctx->state[1]=0xbb67ae85;
    ctx->state[2]=0x3c6ef372; ctx->state[3]=0xa54ff53a;
    ctx->state[4]=0x510e527f; ctx->state[5]=0x9b05688c;
    ctx->state[6]=0x1f83d9ab; ctx->state[7]=0x5be0cd19;
}

static void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len)
{
    for (size_t i = 0; i < len; ++i) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

static void sha256_final(SHA256_CTX *ctx, uint8_t hash[32])
{
    uint32_t i = ctx->datalen;
    if (ctx->datalen < 56) {
        ctx->data[i++] = 0x80;
        while (i < 56) ctx->data[i++] = 0x00;
    } else {
        ctx->data[i++] = 0x80;
        while (i < 64) ctx->data[i++] = 0x00;
        sha256_transform(ctx, ctx->data);
        memset(ctx->data, 0, 56);
    }
    ctx->bitlen += ctx->datalen * 8;
    ctx->data[63] = (uint8_t)(ctx->bitlen);
    ctx->data[62] = (uint8_t)(ctx->bitlen >> 8);
    ctx->data[61] = (uint8_t)(ctx->bitlen >> 16);
    ctx->data[60] = (uint8_t)(ctx->bitlen >> 24);
    ctx->data[59] = (uint8_t)(ctx->bitlen >> 32);
    ctx->data[58] = (uint8_t)(ctx->bitlen >> 40);
    ctx->data[57] = (uint8_t)(ctx->bitlen >> 48);
    ctx->data[56] = (uint8_t)(ctx->bitlen >> 56);
    sha256_transform(ctx, ctx->data);
    for (i = 0; i < 4; ++i) {
        hash[i]    = (ctx->state[0] >> (24-i*8)) & 0xFF;
        hash[i+4]  = (ctx->state[1] >> (24-i*8)) & 0xFF;
        hash[i+8]  = (ctx->state[2] >> (24-i*8)) & 0xFF;
        hash[i+12] = (ctx->state[3] >> (24-i*8)) & 0xFF;
        hash[i+16] = (ctx->state[4] >> (24-i*8)) & 0xFF;
        hash[i+20] = (ctx->state[5] >> (24-i*8)) & 0xFF;
        hash[i+24] = (ctx->state[6] >> (24-i*8)) & 0xFF;
        hash[i+28] = (ctx->state[7] >> (24-i*8)) & 0xFF;
    }
}

/*===========================================================================
 * GENERATE INITIAL CONDITIONS (mirrors MATLAB generateInitialConditions.m)
 *===========================================================================*/
static void generate_initial_conditions(const uint8_t h_blocks[32],
                                        double x0, double y0,
                                        double z0, double w0,
                                        double *X0, double *Y0,
                                        double *Z0, double *W0)
{
    /* XOR blocks 0-7 → X, 8-15 → Y, 16-23 → Z, 24-31 → W */
    uint8_t xv = h_blocks[0];
    for (int i = 1; i < 8;  i++) xv ^= h_blocks[i];
    uint8_t yv = h_blocks[8];
    for (int i = 9; i < 16; i++) yv ^= h_blocks[i];
    uint8_t zv = h_blocks[16];
    for (int i = 17; i < 24; i++) zv ^= h_blocks[i];
    uint8_t wv = h_blocks[24];
    for (int i = 25; i < 32; i++) wv ^= h_blocks[i];

    *X0 = ((double)xv / 256.0) + x0;
    *Y0 = ((double)yv / 256.0) + y0;
    *Z0 = ((double)zv / 256.0) + z0;
    *W0 = ((double)wv / 256.0) + w0;
}

/*===========================================================================
 * CHEN 4D ODE RIGHT-HAND SIDE FUNCTIONS
 *===========================================================================*/
static inline double chen_F(double x, double y, double w, double alpha)
{ return alpha * (y - x) + w; }

static inline double chen_G(double x, double y, double z,
                             double gamma, double epsilon)
{ return gamma * x - x * z + epsilon * y; }

static inline double chen_R(double x, double y, double z, double beta)
{ return x * y - beta * z; }

static inline double chen_S(double y, double z, double w, double lambda)
{ return y * z + lambda * w; }

/*===========================================================================
 * CHEN 4D RK4 INTEGRATION + KEY GENERATION
 * Mirrors MATLAB Chen4D.m exactly.
 * Allocates N doubles per channel on heap; frees after extracting uint8 keys.
 *
 * key_len = N (number of keys needed = IMG_PIXELS after transient)
 * Total iterations = N_TRANSIENT + key_len
 *===========================================================================*/
static int chen4d_generate_keys(double X0, double Y0, double Z0, double W0,
                                 int key_len,
                                 uint8_t *X_key, uint8_t *Y_key,
                                 uint8_t *Z_key, uint8_t *W_key)
{
    int N = N_TRANSIENT + key_len;

    double *Xf = (double*)malloc(N * sizeof(double));
    double *Yf = (double*)malloc(N * sizeof(double));
    double *Zf = (double*)malloc(N * sizeof(double));
    double *Wf = (double*)malloc(N * sizeof(double));

    if (!Xf || !Yf || !Zf || !Wf) {
        xil_printf("ERROR: Chen4D malloc failed\n");
        free(Xf); free(Yf); free(Zf); free(Wf);
        return -1;
    }

    Xf[0] = X0; Yf[0] = Y0; Zf[0] = Z0; Wf[0] = W0;

    double h = H_STEP;
    double alpha   = ALPHA;
    double gamma   = GAMMA_P;
    double epsilon = EPSILON;
    double beta    = BETA_P;
    double lambda  = LAMBDA_P;

    for (int i = 0; i < N - 1; i++) {
        double x = Xf[i], y = Yf[i], z = Zf[i], w = Wf[i];

        double m1 = h * chen_F(x,     y,     w,     alpha);
        double l1 = h * chen_G(x,     y,     z,     gamma, epsilon);
        double o1 = h * chen_R(x,     y,     z,     beta);
        double p1 = h * chen_S(y,     z,     w,     lambda);

        double m2 = h * chen_F(x+m1/2, y+l1/2, w+p1/2, alpha);
        double l2 = h * chen_G(x+m1/2, y+l1/2, z+o1/2, gamma, epsilon);
        double o2 = h * chen_R(x+m1/2, y+l1/2, z+o1/2, beta);
        double p2 = h * chen_S(y+l1/2, z+o1/2, w+p1/2, lambda);

        double m3 = h * chen_F(x+m2/2, y+l2/2, w+p2/2, alpha);
        double l3 = h * chen_G(x+m2/2, y+l2/2, z+o2/2, gamma, epsilon);
        double o3 = h * chen_R(x+m2/2, y+l2/2, z+o2/2, beta);
        double p3 = h * chen_S(y+l2/2, z+o2/2, w+p2/2, lambda);

        double m4 = h * chen_F(x+m3, y+l3, w+p3, alpha);
        double l4 = h * chen_G(x+m3, y+l3, z+o3, gamma, epsilon);
        double o4 = h * chen_R(x+m3, y+l3, z+o3, beta);
        double p4 = h * chen_S(y+l3, z+o3, w+p3, lambda);

        Xf[i+1] = x + (m1 + 2*m2 + 2*m3 + m4) / 6.0;
        Yf[i+1] = y + (l1 + 2*l2 + 2*l3 + l4) / 6.0;
        Zf[i+1] = z + (o1 + 2*o2 + 2*o3 + o4) / 6.0;
        Wf[i+1] = w + (p1 + 2*p2 + 2*p3 + p4) / 6.0;
    }

    /* Extract keys from post-transient sequence */
    for (int i = 0; i < key_len; i++) {
        int idx = N_TRANSIENT + i;
        uint64_t xq = (uint64_t)(fabs(Xf[idx]) * 1e16);
        uint64_t yq = (uint64_t)(fabs(Yf[idx]) * 1e16);
        uint64_t zq = (uint64_t)(fabs(Zf[idx]) * 1e16);
        uint64_t wq = (uint64_t)(fabs(Wf[idx]) * 1e16);
        X_key[i] = (uint8_t)(xq % 256);
        Y_key[i] = (uint8_t)(yq % 256);
        Z_key[i] = (uint8_t)(zq % 256);
        W_key[i] = (uint8_t)(wq % 256);
    }

    free(Xf); free(Yf); free(Zf); free(Wf);
    return 0;
}

/*===========================================================================
 * XOR WHITENING  (Whiten_Image.m)
 * Operates on a flat pixel buffer of length `n`.
 *===========================================================================*/
static void xor_whiten(const uint8_t *in, const uint8_t *key,
                        uint8_t *out, int n)
{
    for (int i = 0; i < n; i++)
        out[i] = in[i] ^ key[i];
}

/*===========================================================================
 * FISHER-YATES SHUFFLE  (FisherYatesNew.m)
 *
 * The MATLAB code:
 *   1. Shuffles pixels inside each 16×16 block using keys starting at
 *      index [block_size*block_size + 1] (1-based) → C index BLOCK_SIZE²
 *   2. Then shuffles the block ORDER using keys[0 .. BLOCK_SIZE²-1]
 *   3. Writes blocks in shuffled order to output.
 *
 * Key values are uint8 cast to double in [0,1) via:
 *   kv = (double)key_byte / 256.0   (we normalise since MATLAB Y_key is uint8)
 *   swap_pos = floor(kv * 1e14) % i   (i is current loop counter)
 *
 * Note: MATLAB Y_key is uint8. In MATLAB the Fisher-Yates uses:
 *   kv = min(max(key_chunk(n-i+1), 0), 0.9999999999)
 * Since Y_key is already uint8 in [0,255], kv is being used directly as
 * if it were a float. This seems like the MATLAB code treats uint8 as a
 * pseudo-float. We replicate exactly: kv = (double)key_byte (0-255),
 * then swap_pos = floor(kv * 1e14) % i + 1 (1-based), converted to 0-based.
 *===========================================================================*/

/* Compute swap position matching MATLAB exactly */
static inline int fy_swap_pos(uint8_t key_val, int i)
{
    /* i is the 1-based loop counter in MATLAB (loop: n downto 2)
     * swap_pos (1-based) = mod(floor(kv*1e14), i) + 1
     * kv in MATLAB is directly the uint8 value (0..255 treated as raw float)
     */
    double kv = (double)key_val;
    /* clamp to [0, 0.9999999999) – since uint8 max is 255 >> 1, this is fine */
    uint64_t val = (uint64_t)(kv * 1e14);
    return (int)(val % (uint64_t)i);  /* 0-based result */
}

static void fisher_yates_shuffle(const uint8_t *in, const uint8_t *Y_key,
                                  uint8_t *out,
                                  int H, int W)
{
    /* Clamp to block-aligned dimensions */
    int h = (H / BLOCK_SIZE) * BLOCK_SIZE;
    int w = (W / BLOCK_SIZE) * BLOCK_SIZE;
    int num_by = h / BLOCK_SIZE;
    int num_bx = w / BLOCK_SIZE;
    int total_blocks = num_by * num_bx;
    int bsq = BLOCK_SIZE * BLOCK_SIZE;
    int klen = IMG_PIXELS; /* total key length */

    /* Allocate temp image */
    uint8_t *temp = (uint8_t*)malloc(h * w);
    if (!temp) { xil_printf("FY malloc failed\n"); return; }

    /* Step 1: Shuffle pixels within each block */
    int key_idx = bsq; /* 0-based, matches MATLAB's key_idx = bsq+1 (1-based) */

    for (int by = 0; by < h; by += BLOCK_SIZE) {
        for (int bx = 0; bx < w; bx += BLOCK_SIZE) {
            /* Flatten block */
            uint8_t flat[BLOCK_SIZE * BLOCK_SIZE];
            for (int r = 0; r < BLOCK_SIZE; r++)
                for (int c = 0; c < BLOCK_SIZE; c++)
                    flat[r * BLOCK_SIZE + c] = in[(by + r) * W + (bx + c)];

            /* Fisher-Yates: i from n downto 2 */
            int n = bsq;
            for (int i = n - 1; i >= 1; i--) {
                /* MATLAB: key_chunk index = n - i (0-based after converting)
                 * key_chunk = Y_key[key_idx .. key_idx+n-1]
                 * MATLAB n-i+1 (1-based) → C: key_chunk[n-1-i] */
                int ki = (key_idx + (n - 1 - i)) % klen;
                int sp = fy_swap_pos(Y_key[ki], i + 1); /* i+1 = MATLAB i */
                /* sp is 0-based swap partner */
                uint8_t tmp = flat[i];
                flat[i] = flat[sp];
                flat[sp] = tmp;
            }

            /* Write shuffled block to temp */
            for (int r = 0; r < BLOCK_SIZE; r++)
                for (int c = 0; c < BLOCK_SIZE; c++)
                    temp[(by + r) * w + (bx + c)] = flat[r * BLOCK_SIZE + c];

            key_idx += bsq;
        }
    }

    /* Step 2: Shuffle block ORDER */
    int *block_indices = (int*)malloc(total_blocks * sizeof(int));
    if (!block_indices) { free(temp); xil_printf("FY block malloc failed\n"); return; }
    for (int i = 0; i < total_blocks; i++) block_indices[i] = i;

    /* block_key = Y_key[0 .. bsq-1] */
    for (int i = total_blocks - 1; i >= 1; i--) {
        int ki = total_blocks - 1 - i; /* maps MATLAB n-i+1 (1-based) to 0-based */
        if (ki >= bsq) ki = ki % bsq;
        int sp = fy_swap_pos(Y_key[ki], i + 1);
        int tmp = block_indices[i];
        block_indices[i] = block_indices[sp];
        block_indices[sp] = tmp;
    }

    /* Step 3: Write blocks in shuffled order to output */
    for (int idx = 0; idx < total_blocks; idx++) {
        int orig_by = (idx / num_bx) * BLOCK_SIZE;
        int orig_bx = (idx % num_bx) * BLOCK_SIZE;

        int shuf_idx = block_indices[idx];
        int shuf_by  = (shuf_idx / num_bx) * BLOCK_SIZE;
        int shuf_bx  = (shuf_idx % num_bx) * BLOCK_SIZE;

        for (int r = 0; r < BLOCK_SIZE; r++)
            for (int c = 0; c < BLOCK_SIZE; c++)
                out[(orig_by + r) * w + (orig_bx + c)] =
                    temp[(shuf_by + r) * w + (shuf_bx + c)];
    }

    free(temp);
    free(block_indices);
}

/*===========================================================================
 * REVERSE FISHER-YATES  (Reverse_FisherYatesNew.m)
 *===========================================================================*/
static void fisher_yates_unshuffle(const uint8_t *in, const uint8_t *Y_key,
                                    uint8_t *out,
                                    int H, int W)
{
    int h = (H / BLOCK_SIZE) * BLOCK_SIZE;
    int w = (W / BLOCK_SIZE) * BLOCK_SIZE;
    int num_by = h / BLOCK_SIZE;
    int num_bx = w / BLOCK_SIZE;
    int total_blocks = num_by * num_bx;
    int bsq = BLOCK_SIZE * BLOCK_SIZE;
    int klen = IMG_PIXELS;

    uint8_t *temp = (uint8_t*)malloc(h * w);
    int *block_order = (int*)malloc(total_blocks * sizeof(int));
    int *reverse_order = (int*)malloc(total_blocks * sizeof(int));
    if (!temp || !block_order || !reverse_order) {
        xil_printf("Rev-FY malloc failed\n");
        free(temp); free(block_order); free(reverse_order);
        return;
    }

    /* Reconstruct the same block shuffle order */
    for (int i = 0; i < total_blocks; i++) block_order[i] = i;
    for (int i = total_blocks - 1; i >= 1; i--) {
        int ki = total_blocks - 1 - i;
        if (ki >= bsq) ki = ki % bsq;
        int sp = fy_swap_pos(Y_key[ki], i + 1);
        int tmp = block_order[i];
        block_order[i] = block_order[sp];
        block_order[sp] = tmp;
    }

    /* Build reverse mapping */
    for (int j = 0; j < total_blocks; j++)
        reverse_order[block_order[j]] = j;

    /* Undo block-level shuffle: copy from in to temp */
    for (int orig_block = 0; orig_block < total_blocks; orig_block++) {
        int shuf_pos = reverse_order[orig_block];

        int shuf_by = (shuf_pos / num_bx) * BLOCK_SIZE;
        int shuf_bx = (shuf_pos % num_bx) * BLOCK_SIZE;
        int orig_by = (orig_block / num_bx) * BLOCK_SIZE;
        int orig_bx = (orig_block % num_bx) * BLOCK_SIZE;

        for (int r = 0; r < BLOCK_SIZE; r++)
            for (int c = 0; c < BLOCK_SIZE; c++)
                temp[(orig_by + r) * w + (orig_bx + c)] =
                    in[(shuf_by + r) * w + (shuf_bx + c)];
    }

    /* Undo pixel shuffle within each block */
    int key_idx = bsq;

    for (int by = 0; by < h; by += BLOCK_SIZE) {
        for (int bx = 0; bx < w; bx += BLOCK_SIZE) {
            uint8_t shuffled[BLOCK_SIZE * BLOCK_SIZE];
            for (int r = 0; r < BLOCK_SIZE; r++)
                for (int c = 0; c < BLOCK_SIZE; c++)
                    shuffled[r * BLOCK_SIZE + c] = temp[(by + r) * w + (bx + c)];

            int n = bsq;
            /* Record all swap operations first */
            int swaps_i[BLOCK_SIZE * BLOCK_SIZE];
            int swaps_j[BLOCK_SIZE * BLOCK_SIZE];
            for (int i = n - 1; i >= 1; i--) {
                int ki = (key_idx + (n - 1 - i)) % klen;
                swaps_i[n - 1 - i] = i;
                swaps_j[n - 1 - i] = fy_swap_pos(Y_key[ki], i + 1);
            }

            /* Replay swaps in reverse */
            uint8_t original[BLOCK_SIZE * BLOCK_SIZE];
            memcpy(original, shuffled, bsq);
            for (int k = n - 2; k >= 0; k--) {
                int i = swaps_i[k];
                int j = swaps_j[k];
                uint8_t tmp = original[i];
                original[i] = original[j];
                original[j] = tmp;
            }

            for (int r = 0; r < BLOCK_SIZE; r++)
                for (int c = 0; c < BLOCK_SIZE; c++)
                    out[(by + r) * W + (bx + c)] = original[r * BLOCK_SIZE + c];

            key_idx += bsq;
        }
    }

    free(temp);
    free(block_order);
    free(reverse_order);
}

/*===========================================================================
 * RNA ENCODING  (RNA_Encoding.m)
 *
 * Rules LUT: rows = rule index (1-8), cols = 2-bit value (0-3) → base char
 * We encode bases as indices: A=0, C=1, G=2, U=3
 *===========================================================================*/

/* Rules LUT: rules_lut[rule][2bit_val] → base index 0=A,1=C,2=G,3=U */
static const uint8_t RULES_LUT[8][4] = {
    {0,1,2,3}, /* Rule 1: A,C,G,U */
    {0,2,1,3}, /* Rule 2: A,G,C,U */
    {3,1,2,0}, /* Rule 3: U,C,G,A */
    {3,2,1,0}, /* Rule 4: U,G,C,A */
    {1,0,3,2}, /* Rule 5: C,A,U,G */
    {2,0,3,1}, /* Rule 6: G,A,U,C */
    {1,3,0,2}, /* Rule 7: C,U,A,G */
    {2,3,0,1}  /* Rule 8: G,U,A,C */
};

/* Reverse LUT: reverse_lut[rule][base_idx] → 2-bit value */
static uint8_t REVERSE_LUT[8][4]; /* computed at init */

static void build_reverse_lut(void)
{
    for (int r = 0; r < 8; r++)
        for (int b = 0; b < 4; b++)
            REVERSE_LUT[r][RULES_LUT[r][b]] = (uint8_t)b;
}

/* RNA arithmetic on base indices (0=A,1=C,2=G,3=U) */
static inline uint8_t rna_add (uint8_t p, uint8_t k) { return (p + k) % 4; }
static inline uint8_t rna_sub (uint8_t p, uint8_t k) { return (p - k + 4) % 4; }
static inline uint8_t rna_xor (uint8_t p, uint8_t k) { return p ^ k; }
static inline uint8_t rna_xnor(uint8_t p, uint8_t k) { return (p ^ k) ^ 3; }

static void rna_encode(const uint8_t *in, const uint8_t *Z_key,
                        uint8_t *out, int n)
{
    for (int px = 0; px < n; px++) {
        uint8_t plain_byte = in[px];
        uint8_t key_byte   = Z_key[px];

        /* Key-derived indices (MATLAB bits are 1-based from MSB)
         * key_bits[6:8] (MATLAB, 1-based) = bits 2..0 (LSBs, 0-based)
         * rule_idx = lower 3 bits → [0..7] → +1 = [1..8]
         * op_idx   = bits [4:5] (MATLAB) = bits [3..2] (0-based) → [0..3] → +1 */
        uint8_t rule_idx = (key_byte & 0x07);          /* 3 LSBs → 0..7 */
        uint8_t op_idx   = (key_byte >> 2) & 0x03;     /* bits 3..2 → 0..3 */

        /* Split bytes into 4 groups of 2 bits (MSB first) */
        uint8_t p_grp[4], k_grp[4];
        for (int b = 0; b < 4; b++) {
            p_grp[b] = (plain_byte >> (6 - 2*b)) & 0x03;
            k_grp[b] = (key_byte   >> (6 - 2*b)) & 0x03;
        }

        /* Encode 2-bit groups to RNA bases */
        uint8_t p_rna[4], k_rna[4];
        for (int b = 0; b < 4; b++) {
            p_rna[b] = RULES_LUT[rule_idx][p_grp[b]];
            k_rna[b] = RULES_LUT[rule_idx][k_grp[b]];
        }

        /* Apply operation */
        uint8_t res[4];
        for (int b = 0; b < 4; b++) {
            switch (op_idx) {
                case 0: res[b] = rna_add (p_rna[b], k_rna[b]); break;
                case 1: res[b] = rna_sub (p_rna[b], k_rna[b]); break;
                case 2: res[b] = rna_xor (p_rna[b], k_rna[b]); break;
                case 3: res[b] = rna_xnor(p_rna[b], k_rna[b]); break;
                default: res[b] = p_rna[b]; break;
            }
        }

        /* Decode result bases back to 2-bit values using plain rule */
        uint8_t result_byte = 0;
        for (int b = 0; b < 4; b++) {
            uint8_t bits2 = REVERSE_LUT[rule_idx][res[b]];
            result_byte |= (bits2 << (6 - 2*b));
        }

        out[px] = result_byte;
    }
}

/*===========================================================================
 * RNA DECODING  (RNA_Decoding.m)
 *===========================================================================*/
static void rna_decode(const uint8_t *in, const uint8_t *Z_key,
                        uint8_t *out, int n)
{
    for (int px = 0; px < n; px++) {
        uint8_t enc_byte = in[px];
        uint8_t key_byte = Z_key[px];

        uint8_t rule_idx = (key_byte & 0x07);
        uint8_t op_idx   = (key_byte >> 2) & 0x03;

        uint8_t e_grp[4], k_grp[4];
        for (int b = 0; b < 4; b++) {
            e_grp[b] = (enc_byte >> (6 - 2*b)) & 0x03;
            k_grp[b] = (key_byte >> (6 - 2*b)) & 0x03;
        }

        uint8_t e_rna[4], k_rna[4];
        for (int b = 0; b < 4; b++) {
            e_rna[b] = RULES_LUT[rule_idx][e_grp[b]];
            k_rna[b] = RULES_LUT[rule_idx][k_grp[b]];
        }

        /* Inverse operations */
        uint8_t res[4];
        for (int b = 0; b < 4; b++) {
            switch (op_idx) {
                case 0: res[b] = rna_sub (e_rna[b], k_rna[b]); break; /* inv add */
                case 1: res[b] = rna_add (e_rna[b], k_rna[b]); break; /* inv sub */
                case 2: res[b] = rna_xor (e_rna[b], k_rna[b]); break; /* self-inv */
                case 3: res[b] = rna_xnor(e_rna[b], k_rna[b]); break; /* self-inv */
                default: res[b] = e_rna[b]; break;
            }
        }

        uint8_t result_byte = 0;
        for (int b = 0; b < 4; b++) {
            uint8_t bits2 = REVERSE_LUT[rule_idx][res[b]];
            result_byte |= (bits2 << (6 - 2*b));
        }

        out[px] = result_byte;
    }
}

/*===========================================================================
 * NPCR and UACI  (matches MATLAB npcr_uaci)
 *===========================================================================*/
static void compute_npcr_uaci(const uint8_t *orig, const uint8_t *enc,
                               int n, double *npcr, double *uaci)
{
    uint64_t diff_count = 0;
    double uaci_sum = 0.0;

    for (int i = 0; i < n; i++) {
        if (orig[i] != enc[i]) diff_count++;
        uaci_sum += fabs((double)orig[i] - (double)enc[i]) / 255.0;
    }

    *npcr = ((double)diff_count / (double)n) * 100.0;
    *uaci = (uaci_sum / (double)n) * 100.0;
}

/*===========================================================================
 * UART HELPERS
 *===========================================================================*/
static XUartPs uart_inst;

static void uart_send_bytes(const uint8_t *data, uint32_t len)
{
    uint32_t sent = 0;
    uint32_t retry = 0;

    while (sent < len) {
        uint32_t chunk = (len - sent > UART_BURST) ? UART_BURST : (len - sent);
        uint32_t n = XUartPs_Send(&uart_inst, (uint8_t*)(data + sent), chunk);
        if (n == 0) {
            usleep(500);
            retry++;
            if (retry > 5000) {
                xil_printf("UART TX timeout at byte %u\n", (unsigned)sent);
                return;
            }
            continue;
        }
        sent += n;
        retry = 0;
        while (XUartPs_IsSending(&uart_inst)) usleep(50);
    }
}

/**
 * Send one image packet:
 *   [MAGIC_BYTE] [stage_id] [width_hi] [width_lo] [height_hi] [height_lo]
 *   [n_bytes (4 bytes, big-endian)] [pixel data ...]
 */
static void uart_send_image(uint8_t stage_id, const uint8_t *pixels,
                             uint16_t width, uint16_t height, uint8_t bpp)
{
    uint32_t nbytes = (uint32_t)width * height * bpp;

    uint8_t hdr[10];
    hdr[0] = MAGIC_BYTE;
    hdr[1] = stage_id;
    hdr[2] = (uint8_t)(width  >> 8);
    hdr[3] = (uint8_t)(width  & 0xFF);
    hdr[4] = (uint8_t)(height >> 8);
    hdr[5] = (uint8_t)(height & 0xFF);
    hdr[6] = bpp;
    hdr[7] = (uint8_t)(nbytes >> 16);
    hdr[8] = (uint8_t)(nbytes >> 8);
    hdr[9] = (uint8_t)(nbytes & 0xFF);

    uart_send_bytes(hdr, 10);
    uart_send_bytes(pixels, nbytes);
}

/**
 * Send metrics packet as ASCII (terminated by '\n'):
 *   [MAGIC_BYTE] [PKT_METRICS] [length_byte] [ASCII string]
 */
static void uart_send_metrics(double npcr, double uaci,
                               double enc_ms, double dec_ms)
{
    char buf[128];
    int len = snprintf(buf, sizeof(buf),
                       "NPCR=%.4f%%,UACI=%.4f%%,ENC_MS=%.3f,DEC_MS=%.3f\n",
                       npcr, uaci, enc_ms, dec_ms);

    uint8_t hdr[3];
    hdr[0] = MAGIC_BYTE;
    hdr[1] = PKT_METRICS;
    hdr[2] = (uint8_t)len;
    uart_send_bytes(hdr, 3);
    uart_send_bytes((uint8_t*)buf, (uint32_t)len);
}

/*===========================================================================
 * MAIN
 *===========================================================================*/
int main(void)
{
    xil_printf("\n=== Chen 4D Image Cryptosystem Starting ===\n");

    /*----------------------------------------------------------------------
     * UART INIT
     *--------------------------------------------------------------------*/
    XUartPs_Config *uart_cfg = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    if (XUartPs_CfgInitialize(&uart_inst, uart_cfg,
                               uart_cfg->BaseAddress) != XST_SUCCESS) {
        xil_printf("ERROR: UART init failed\n");
        return -1;
    }
    XUartPs_SetBaudRate(&uart_inst, BAUD_RATE);

    /*----------------------------------------------------------------------
     * ALLOCATE BUFFERS
     *--------------------------------------------------------------------*/
    int n = IMG_PIXELS;   /* total pixels */

    uint8_t *orig    = (uint8_t*)malloc(n);
    uint8_t *stage1  = (uint8_t*)malloc(n);  /* after XOR(X) */
    uint8_t *stage2  = (uint8_t*)malloc(n);  /* after FY(Y)  */
    uint8_t *stage3  = (uint8_t*)malloc(n);  /* after RNA(Z) */
    uint8_t *cipher  = (uint8_t*)malloc(n);  /* after XOR(W) */
    uint8_t *ds1     = (uint8_t*)malloc(n);  /* decrypt: after XOR(W)  */
    uint8_t *ds2     = (uint8_t*)malloc(n);  /* decrypt: after RNA_dec */
    uint8_t *ds3     = (uint8_t*)malloc(n);  /* decrypt: after Rev_FY  */
    uint8_t *decrypted=(uint8_t*)malloc(n);  /* final decrypted */

    uint8_t *X_key  = (uint8_t*)malloc(n);
    uint8_t *Y_key  = (uint8_t*)malloc(n);
    uint8_t *Z_key  = (uint8_t*)malloc(n);
    uint8_t *W_key  = (uint8_t*)malloc(n);

    if (!orig || !stage1 || !stage2 || !stage3 || !cipher ||
        !ds1  || !ds2    || !ds3    || !decrypted ||
        !X_key|| !Y_key  || !Z_key  || !W_key) {
        xil_printf("ERROR: Buffer allocation failed\n");
        goto cleanup;
    }


    xil_printf("[1] Extracting image pixels...\n");
    for (int i = 0; i < n; i++) {
        orig[i] = (uint8_t)(test_image[i]);
    }

    /*----------------------------------------------------------------------
     * SHA-256 HASH OF IMAGE
     *--------------------------------------------------------------------*/
    xil_printf("[2] Computing SHA-256...\n");
    uint8_t hash[32];
    SHA256_CTX sha_ctx;
    sha256_init(&sha_ctx);
    sha256_update(&sha_ctx, orig, n);
    sha256_final(&sha_ctx, hash);

    xil_printf("SHA-256: ");
    for (int i = 0; i < 32; i++) xil_printf("%02x", hash[i]);
    xil_printf("\n");

    /*----------------------------------------------------------------------
     * GENERATE INITIAL CONDITIONS
     *--------------------------------------------------------------------*/
    double X0, Y0, Z0, W0;
    generate_initial_conditions(hash,
                                 X0_OFFSET, Y0_OFFSET, Z0_OFFSET, W0_OFFSET,
                                 &X0, &Y0, &Z0, &W0);
    xil_printf("ICs: X0=%.6f Y0=%.6f Z0=%.6f W0=%.6f\n", X0, Y0, Z0, W0);

    /*----------------------------------------------------------------------
     * CHEN 4D KEY GENERATION
     *--------------------------------------------------------------------*/
    xil_printf("[3] Running Chen4D RK4 (%d transient + %d keys)...\n",
               N_TRANSIENT, n);

    if (chen4d_generate_keys(X0, Y0, Z0, W0, n,
                              X_key, Y_key, Z_key, W_key) != 0)
        goto cleanup;

    xil_printf("    Keys generated OK.\n");

    /*----------------------------------------------------------------------
     * ENCRYPTION
     *--------------------------------------------------------------------*/
    xil_printf("[4] Encrypting...\n");
    XTime t0, t1;
    Xil_DCacheFlush();
    XTime_GetTime(&t0);

    /* Stage 1: XOR with X_key */
    xor_whiten(orig, X_key, stage1, n);

    /* Stage 2: Fisher-Yates shuffle with Y_key */
    build_reverse_lut(); /* prepare RNA decode LUT too */
    fisher_yates_shuffle(stage1, Y_key, stage2, IMG_HEIGHT, IMG_WIDTH);

    /* Stage 3: RNA encoding with Z_key */
    rna_encode(stage2, Z_key, stage3, FY_PIXELS);

    /* Stage 4: XOR with W_key (final cipher) */
    xor_whiten(stage3, W_key, cipher, FY_PIXELS);

    uint8_t *result=(uint8_t*)malloc(n);  /* final decrypted */

    result = (*cipher) * 0.001;

    XTime_GetTime(&t1);
    double enc_ms = (double)(t1 - t0) * 1000.0 / (double)COUNTS_PER_SECOND;
    xil_printf("    Encryption done in %.3f ms\n", enc_ms);

    /*----------------------------------------------------------------------
     * DECRYPTION
     *--------------------------------------------------------------------*/
    xil_printf("[5] Decrypting...\n");
    XTime t2, t3;
    XTime_GetTime(&t2);

    /* Reverse Stage 4: XOR with W_key */
    xor_whiten(result, W_key, ds1, FY_PIXELS);

    /* Reverse Stage 3: RNA decoding */
    rna_decode(ds1, Z_key, ds2, FY_PIXELS);

    /* Reverse Stage 2: Reverse Fisher-Yates */
    fisher_yates_unshuffle(ds2, Y_key, ds3, IMG_HEIGHT, IMG_WIDTH);

    /* Reverse Stage 1: XOR with X_key */
    xor_whiten(ds3, X_key, decrypted, n);

    XTime_GetTime(&t3);
    double dec_ms = (double)(t3 - t2) * 1000.0 / (double)COUNTS_PER_SECOND;
    xil_printf("    Decryption done in %.3f ms\n", dec_ms);

    /* Verify */
    int match = 1;
    for (int i = 0; i < FY_PIXELS; i++) {
        if (decrypted[i] != orig[i]) { match = 0; break; }
    }
    xil_printf("    Decryption verify: %s\n", match ? "PASS" : "FAIL");

    /*----------------------------------------------------------------------
     * NPCR / UACI
     *--------------------------------------------------------------------*/
    double npcr, uaci;
    compute_npcr_uaci(orig, cipher, FY_PIXELS, &npcr, &uaci);
    xil_printf("NPCR = %.4f %%   UACI = %.4f %%\n", npcr, uaci);

    /*----------------------------------------------------------------------
     * TRANSMIT ALL IMAGES VIA UART
     *--------------------------------------------------------------------*/
    xil_printf("[6] Sending images via UART...\n");

    /* Small delay to allow Python receiver to settle */
    usleep(200000);

    uart_send_image(IMG_ORIGINAL,   orig,      IMG_WIDTH, IMG_HEIGHT, 1);
    xil_printf("    Sent: original\n");

    uart_send_image(IMG_STAGE1,     stage1,    IMG_WIDTH, IMG_HEIGHT, 1);
    xil_printf("    Sent: stage1 (XOR whitened)\n");

    uart_send_image(IMG_STAGE2,     stage2,    FY_W,      FY_H,       1);
    xil_printf("    Sent: stage2 (Fisher-Yates)\n");

    uart_send_image(IMG_STAGE3,     stage3,    FY_W,      FY_H,       1);
    xil_printf("    Sent: stage3 (RNA encoded)\n");

    uart_send_image(IMG_ENCRYPTED,  cipher,    FY_W,      FY_H,       1);
    xil_printf("    Sent: final cipher\n");

    uart_send_image(IMG_DEC_STAGE1, ds1,       FY_W,      FY_H,       1);
    xil_printf("    Sent: dec stage1 (XOR W reversed)\n");

    uart_send_image(IMG_DEC_STAGE2, ds2,       FY_W,      FY_H,       1);
    xil_printf("    Sent: dec stage2 (RNA decoded)\n");

    uart_send_image(IMG_DEC_STAGE3, ds3,       IMG_WIDTH, IMG_HEIGHT, 1);
    xil_printf("    Sent: dec stage3 (FY reversed)\n");

    uart_send_image(IMG_DECRYPTED,  decrypted, IMG_WIDTH, IMG_HEIGHT, 1);
    xil_printf("    Sent: final decrypted\n");

    uart_send_metrics(npcr, uaci, enc_ms, dec_ms);
    xil_printf("    Sent: metrics\n");

    xil_printf("=== All done. ===\n");

cleanup:
    free(orig); free(stage1); free(stage2); free(stage3); free(cipher);
    free(ds1);  free(ds2);    free(ds3);    free(decrypted);
    free(X_key); free(Y_key); free(Z_key); free(W_key);
    return 0;
}
