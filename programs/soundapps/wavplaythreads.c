#include <stdio.h>
#include <fcntl.h>
#include <wgsipc.h>
#include <stdlib.h>
#include <wgslib.h>
#include <termio.h>
#include <winlib.h>

#define RCHNK_FORMAT	1
#define RCHNK_DATA	2

typedef struct riff {
	char RiffIdent[4];
	long TotalSize;
	char RiffType[4];
} Riff;

typedef struct rchunk {
	char Ident[4];
	long ChSize;
} RChunk;

typedef struct rform {
	int Chan1;
	int Chan2;
	long SampRate;
	long ByteSec;
	int ByteSamp;
	int BitSamp;
	int Unused;
} RifForm;

typedef struct data_s {
  int pauseflag;
} pausestruct;

struct termios tio;

void playthread();
void loadthread();

RifForm Format;

struct wmutex pausemutex = {-1, -1};
struct wmutex buf0mutex  = {-1, -1};
struct wmutex buf1mutex  = {-1, -1};

char * playbuf, *buf;
char * songname;
void * textbar;
long inread;
int  numofsongs;
int  lastbuffer = 3;
int  multiplier = 1;

char **allsongs;

//int fix_fft(fixed fr[], fixed fi[], int m, int inverse);

void mysleep(int seconds) {
  int channel;
  char * MsgP;

  channel = makeChan();
  setTimer(-1, seconds*1000, 0, channel, PMSG_Alarm);
  recvMsg(channel,(void *)&MsgP);
}

void pauseplay(void * button) {
  pausestruct * pauses;

  pauses = JWGetData(button);

  if(!pauses->pauseflag) {
    pauses->pauseflag = 1;
    getMutex(&pausemutex);    
  } else {
    pauses->pauseflag = 0;
    relMutex(&pausemutex);
  }
}

void main(int argc, char *argv[]) {
  void * app,*wnd, *pausebut, *songlist;
  pausestruct * pauses;
  int songnum;
	
  if (argc < 2) {
    fprintf(stderr,"Usage: %s [-s] file1.wav [file2.wav file3.wav ...]\n       -s sample smoothing. Sounds better, Uses more CPU.\n", argv[0]);
    exit(1);
  }

  if(!strcmp(argv[1],"-s")) {
    multiplier = 2;
    if(argc < 3) {
      fprintf(stderr,"Usage: %s [-s] file1.wav [file2.wav file3.wav ...]\n       -s sample smoothing. Sounds better, Uses more CPU.\n", argv[0]);
      exit(1);
    }
  }

  numofsongs = argc;
  allsongs   = argv; 

  pauses = (pausestruct *)malloc(sizeof(pausestruct));
  pauses->pauseflag = 0;

  app = JAppInit(NULL, 0);
  wnd = JWndInit(NULL, "Wave Player", JWndF_Resizable);

  JWSetBounds(wnd, 8,8, 96, 80);
//  JWSetMin(wnd,64,24);
 // JWSetMax(wnd,96,80);
 // JWndSetProp(wnd);

  JAppSetMain(app,wnd);

  ((JCnt *)wnd)->Orient = JCntF_TopBottom;

  textbar = JTxfInit(NULL);
  pausebut = JButInit(NULL, "play/pause");
 // songlist = JTxtInit(NULL);

  JCntAdd(wnd, textbar);
  JCntAdd(wnd, pausebut);
 // JCntAdd(wnd, songlist);
/*
  if(multiplier > 1)
    songnum = 2;    
  else
    songnum = 1;

  for(;songnum<argc;songnum++) {
    JTxtAppend(songlist,argv[songnum]);
    JTxtAppend(songlist,"\n");
  }
*/
  JWSetData(pausebut, pauses);

  JWinCallback(pausebut, JBut, Clicked, pauseplay);

  retexit(1);

  newThread(loadthread, STACK_DFL, NULL);
  newThread(playthread, STACK_DFL, NULL);

  JWinShow(wnd);
  JAppLoop(app);
}

void loadthread() {
  int Channel;
  char * MsgP;
  FILE    *fp; 
  Riff    RiffHdr;
  RChunk  Chunk;
  int     done=0;
  int     song;
  int buffer = 0;

  if(multiplier > 1)
    song = 2;
  else
    song = 1;

  for(;song<numofsongs;song++) {
    if(buffer)
      getMutex(&buf1mutex);
    else
      getMutex(&buf0mutex);

    //printf("%s\n", allsongs[song]);

    fp = fopen(allsongs[song], "rb");
    if(fp) {
      fread(&RiffHdr,1,sizeof(Riff),fp);

      if (RiffHdr.RiffIdent[0]!='R' || RiffHdr.RiffIdent[1]!='I') {
        fprintf(stderr,"Not a wav file!\n");
        break;
      }

      while (!done) {
        fread(&Chunk,1,sizeof(RChunk),fp);

        if (Chunk.Ident[0]=='f' && Chunk.Ident[1]=='m') {
          fread(&Format,1,Chunk.ChSize,fp);
        } else if (Chunk.Ident[0]=='d') {
          done=1;
	      } else {
          fseek(fp,Chunk.ChSize,SEEK_CUR);
        }
      }
      done = 0;

      buf = malloc(Chunk.ChSize);

      inread = fread(buf, 1, Chunk.ChSize, fp);

      songname = allsongs[song];

      if(song+1 == numofsongs)
        lastbuffer = buffer;

      if(buffer) {
        relMutex(&buf1mutex);
        buffer = 0;
      } else {
        relMutex(&buf0mutex);
        buffer = 1;
      }
    }
  }

  //TRY REMOVING THIS ... 
  Channel = makeChan();
  recvMsg(Channel,(void *)&MsgP);
}

void playthread() {
  long lefttoplay, minutes, seconds, samprate;
  int amount;
  int digiChan;
  RifForm playformat;
  char * bufstart;  
  char * string;
  char * playingsongname;
  int buffer = 0;
 
  //if smoothing is being used
  int i,j, tempbufinuse=0;
  unsigned char oldsample, newsample, runningcount, delta;
  unsigned char * tempbuf, * tempbuf1, * tempbufptr;

  //Assuming 8bit mono for the remaining minutes:seconds counter

  string = (char *)malloc(30);  

  digiChan = open("/dev/mixer",O_READ|O_WRITE);

  if (digiChan == -1) {
    fprintf(stderr,"Digi device not loaded\n");
    exit(1);
  }

  while(1) {

    JTxfSetText(textbar, "Loading...");

    if(buffer)
      getMutex(&buf1mutex);
    else
      getMutex(&buf0mutex);

    playingsongname = songname;

    memcpy(&playformat, &Format, sizeof(RifForm));

    lefttoplay = inread;
    bufstart = playbuf = buf;

    oldsample = *playbuf;
    runningcount = oldsample;
    playbuf++;
    samprate = playformat.SampRate * multiplier;
    tempbuf  = malloc(samprate);
    tempbuf1 = malloc(samprate); 

    sendCon(digiChan, IO_CONTROL, 0xc0, 8, (unsigned int) samprate, 1, 2);

    //printf("Changing samplerate to %d\n",(unsigned int)playformat.SampRate);

    mysleep(1);

    while (lefttoplay > 0) {
      getMutex(&pausemutex);

      if (lefttoplay > playformat.SampRate)
        amount = samprate;
      else 
        amount = lefttoplay * multiplier;

      if(!tempbufinuse)
        tempbufptr = tempbuf;
      else
        tempbufptr = tempbuf1;

      for(i=0;i<amount;i=i+multiplier) {
        newsample = *playbuf;
        playbuf++;
        if(newsample > oldsample) {
          delta = (newsample - oldsample) / multiplier;
          for(j=0;j<multiplier;j++) {
            runningcount = runningcount + delta;
            *tempbufptr  = runningcount;
            tempbufptr++;
          }
        } else {
          delta = (oldsample - newsample) / multiplier;
          for(j=0;j<multiplier;j++) {
            runningcount = runningcount - delta;
            *tempbufptr  = runningcount;
            tempbufptr++;
          }
        }
        oldsample    = newsample;
        runningcount = oldsample; 
      }
      
      if(!tempbufinuse) {
        tempbufinuse = 1;
        write(digiChan, tempbuf, amount);
      } else {
        tempbufinuse = 0;
        write(digiChan, tempbuf1, amount);
      }

      minutes = (lefttoplay/playformat.SampRate)/60;
      seconds = (lefttoplay/playformat.SampRate) - (minutes * 60);

      if(seconds < 10)
        sprintf(string, "%s %ld:0%ld",playingsongname, minutes, seconds);
      else
        sprintf(string, "%s %ld:%ld",playingsongname, minutes, seconds);

      JTxfSetText(textbar, string);

      lefttoplay = lefttoplay - playformat.SampRate;

      relMutex(&pausemutex);
    }
    free(bufstart);

    if(lastbuffer == buffer)
      break;

    if(buffer) {
      relMutex(&buf1mutex);
      buffer = 0;
    } else {
      relMutex(&buf0mutex);
      buffer = 1;
    }
  }

  close(digiChan);
  JTxfSetText(textbar, "Playlist Finished.");
}

// Greg's Note: I'm using this guys FFT routine and lookup tables to 
// make the graphical equilizer display in wavplaythreads -- Thanks! --

/*      fix_fft.c - Fixed-point Fast Fourier Transform  */

/*
Written by:  Tom Roberts  11/8/89
Made portable:  Malcolm Slaney 12/15/94 malcolm@interval.com

*/

/* FIX_MPY() - fixed-point multiplication macro.
   This macro is a statement, not an expression (uses asm).
   BEWARE: make sure _DX is not clobbered by evaluating (A) or DEST.
   args are all of type fixed.
   Scaling ensures that 32767*32767 = 32767. */

#define FIX_MPY(DEST,A,B)       DEST = ((long)(A) * (long)(B))>>15

#define N_WAVE          1024    /* dimension of Sinewave[] */
#define LOG2_N_WAVE     10      /* log2(N_WAVE) */
#define N_LOUD          100     /* dimension of Loudampl[] */

#ifndef fixed
#define fixed short
#endif

extern fixed Sinewave[N_WAVE]; /* placed at end of this file for clarity */
extern fixed Loudampl[N_LOUD];
fixed fix_mpy(fixed a, fixed b);

/*
        fix_fft() - perform fast Fourier transform.

        if n>0 FFT is done, if n<0 inverse FFT is done
        fr[n],fi[n] are real,imaginary arrays, INPUT AND RESULT.
        size of data = 2**m
        set inverse to 0=dft, 1=idft
*/
/*
int fix_fft(fixed fr[], fixed fi[], int m, int inverse){
  int mr,nn,i,j,l,k,istep, n, scale, shift;
  fixed qr,qi,tr,ti,wr,wi,t;

  n = 1<<m;

  if(n > N_WAVE)
    return -1;

    mr = 0;
    nn = n - 1;
    scale = 0;

    // decimation in time - re-order data 

    for(m=1; m<=nn; ++m) {
      l = n;

      do {
        l >>= 1;
      } while(mr+l > nn);

      mr = (mr & (l-1)) + l;

      if(mr <= m) 
        continue;

      tr     = fr[m];
      fr[m]  = fr[mr];
      fr[mr] = tr;
      ti     = fi[m];
      fi[m]  = fi[mr];
      fi[mr] = ti;
    }

    l = 1;
    k = LOG2_N_WAVE-1;

    while(l < n) {
      if(inverse) {

        // variable scaling, depending upon data 

        shift = 0;

        for(i=0; i<n; ++i) {
          j = fr[i];

          if(j < 0)
            j = -j;

          m = fi[i];

          if(m < 0)
            m = -m;

          if(j > 16383 || m > 16383) {
             shift = 1;
             break;
          }
        }
        if(shift)
          ++scale;
      } else {

        // fixed scaling, for proper normalization -
        // there will be log2(n) passes, so this
        // results in an overall factor of 1/n,
        // distributed to maximize arithmetic accuracy. 

        shift = 1;
      }

      // it may not be obvious, but the shift will be performed
      // on each data point exactly once, during this pass. 

      istep = l << 1;

      for(m=0; m<l; ++m) {
        j = m << k;

        // 0 <= j < N_WAVE/2 

        wr =  Sinewave[j+N_WAVE/4];
        wi = -Sinewave[j];

        if(inverse)
          wi = -wi;

          if(shift) {
            wr >>= 1;
            wi >>= 1;
          }

          for(i=m; i<n; i+=istep) {
            j = i + l;
            tr = fix_mpy(wr,fr[j]) - fix_mpy(wi,fi[j]);
            ti = fix_mpy(wr,fi[j]) + fix_mpy(wi,fr[j]);
            qr = fr[i];
            qi = fi[i];

            if(shift) {
              qr >>= 1;
              qi >>= 1;
            }

            fr[j] = qr - tr;
            fi[j] = qi - ti;
            fr[i] = qr + tr;
            fi[i] = qi + ti;
          }
        }
        --k;
        l = istep;
      }

    return scale;
}
*/
#if N_WAVE != 1024
  ERROR: N_WAVE != 1024
#endif

fixed Sinewave[1024] = {
      0,    201,    402,    603,    804,   1005,   1206,   1406,
   1607,   1808,   2009,   2209,   2410,   2610,   2811,   3011,
   3211,   3411,   3611,   3811,   4011,   4210,   4409,   4608,
   4807,   5006,   5205,   5403,   5601,   5799,   5997,   6195,
   6392,   6589,   6786,   6982,   7179,   7375,   7571,   7766,
   7961,   8156,   8351,   8545,   8739,   8932,   9126,   9319,
   9511,   9703,   9895,  10087,  10278,  10469,  10659,  10849,
  11038,  11227,  11416,  11604,  11792,  11980,  12166,  12353,
  12539,  12724,  12909,  13094,  13278,  13462,  13645,  13827,
  14009,  14191,  14372,  14552,  14732,  14911,  15090,  15268,
  15446,  15623,  15799,  15975,  16150,  16325,  16499,  16672,
  16845,  17017,  17189,  17360,  17530,  17699,  17868,  18036,
  18204,  18371,  18537,  18702,  18867,  19031,  19194,  19357,
  19519,  19680,  19840,  20000,  20159,  20317,  20474,  20631,
  20787,  20942,  21096,  21249,  21402,  21554,  21705,  21855,
  22004,  22153,  22301,  22448,  22594,  22739,  22883,  23027,
  23169,  23311,  23452,  23592,  23731,  23869,  24006,  24143,
  24278,  24413,  24546,  24679,  24811,  24942,  25072,  25201,
  25329,  25456,  25582,  25707,  25831,  25954,  26077,  26198,
  26318,  26437,  26556,  26673,  26789,  26905,  27019,  27132,
  27244,  27355,  27466,  27575,  27683,  27790,  27896,  28001,
  28105,  28208,  28309,  28410,  28510,  28608,  28706,  28802,
  28897,  28992,  29085,  29177,  29268,  29358,  29446,  29534,
  29621,  29706,  29790,  29873,  29955,  30036,  30116,  30195,
  30272,  30349,  30424,  30498,  30571,  30643,  30713,  30783,
  30851,  30918,  30984,  31049,
  31113,  31175,  31236,  31297,
  31356,  31413,  31470,  31525,  31580,  31633,  31684,  31735,
  31785,  31833,  31880,  31926,  31970,  32014,  32056,  32097,
  32137,  32176,  32213,  32249,  32284,  32318,  32350,  32382,
  32412,  32441,  32468,  32495,  32520,  32544,  32567,  32588,
  32609,  32628,  32646,  32662,  32678,  32692,  32705,  32717,
  32727,  32736,  32744,  32751,  32757,  32761,  32764,  32766,
  32767,  32766,  32764,  32761,  32757,  32751,  32744,  32736,
  32727,  32717,  32705,  32692,  32678,  32662,  32646,  32628,
  32609,  32588,  32567,  32544,  32520,  32495,  32468,  32441,
  32412,  32382,  32350,  32318,  32284,  32249,  32213,  32176,
  32137,  32097,  32056,  32014,  31970,  31926,  31880,  31833,
  31785,  31735,  31684,  31633,  31580,  31525,  31470,  31413,
  31356,  31297,  31236,  31175,  31113,  31049,  30984,  30918,
  30851,  30783,  30713,  30643,  30571,  30498,  30424,  30349,
  30272,  30195,  30116,  30036,  29955,  29873,  29790,  29706,
  29621,  29534,  29446,  29358,  29268,  29177,  29085,  28992,
  28897,  28802,  28706,  28608,  28510,  28410,  28309,  28208,
  28105,  28001,  27896,  27790,  27683,  27575,  27466,  27355,
  27244,  27132,  27019,  26905,  26789,  26673,  26556,  26437,
  26318,  26198,  26077,  25954,  25831,  25707,  25582,  25456,
  25329,  25201,  25072,  24942,  24811,  24679,  24546,  24413,
  24278,  24143,  24006,  23869,  23731,  23592,  23452,  23311,
  23169,  23027,  22883,  22739,  22594,  22448,  22301,  22153,
  22004,  21855,  21705,  21554,  21402,  21249,  21096,  20942,
  20787,  20631,  20474,  20317,  20159,  20000,  19840,  19680,
  19519,  19357,  19194,  19031,  18867,  18702,  18537,  18371,
  18204,  18036,  17868,  17699,  17530,  17360,  17189,  17017,
  16845,  16672,  16499,  16325,  16150,  15975,  15799,  15623,
  15446,  15268,  15090,  14911,  14732,  14552,  14372,  14191,
  14009,  13827,  13645,  13462,  13278,  13094,  12909,  12724,
  12539,  12353,  12166,  11980,  11792,  11604,  11416,  11227,
  11038,  10849,  10659,  10469,  10278,  10087,   9895,   9703,
   9511,   9319,   9126,   8932,   8739,   8545,   8351,   8156,
   7961,   7766,   7571,   7375,   7179,   6982,   6786,   6589,
   6392,   6195,   5997,   5799,   5601,   5403,   5205,   5006,
   4807,   4608,   4409,   4210,   4011,   3811,   3611,   3411,
   3211,   3011,   2811,   2610,   2410,   2209,   2009,   1808,
   1607,   1406,   1206,   1005,    804,    603,    402,    201,
      0,   -201,   -402,   -603,   -804,  -1005,  -1206,  -1406,
  -1607,  -1808,  -2009,  -2209,  -2410,  -2610,  -2811,  -3011,
  -3211,  -3411,  -3611,  -3811,  -4011,  -4210,  -4409,  -4608,
  -4807,  -5006,  -5205,  -5403,  -5601,  -5799,  -5997,  -6195,
  -6392,  -6589,  -6786,  -6982,  -7179,  -7375,  -7571,  -7766,
  -7961,  -8156,  -8351,  -8545,  -8739,  -8932,  -9126,  -9319,
  -9511,  -9703,  -9895, -10087, -10278, -10469, -10659, -10849,
 -11038, -11227, -11416, -11604, -11792, -11980, -12166, -12353,
 -12539, -12724, -12909, -13094, -13278, -13462, -13645, -13827,
 -14009, -14191, -14372, -14552, -14732, -14911, -15090, -15268,
 -15446, -15623, -15799, -15975, -16150, -16325, -16499, -16672,
 -16845, -17017, -17189, -17360, -17530, -17699, -17868, -18036,
 -18204, -18371, -18537, -18702, -18867, -19031, -19194, -19357,
 -19519, -19680, -19840, -20000, -20159, -20317, -20474, -20631,
 -20787, -20942, -21096, -21249, -21402, -21554, -21705, -21855,
 -22004, -22153, -22301, -22448, -22594, -22739, -22883, -23027,
 -23169, -23311, -23452, -23592, -23731, -23869, -24006, -24143,
 -24278, -24413, -24546, -24679, -24811, -24942, -25072, -25201,
 -25329, -25456, -25582, -25707, -25831, -25954, -26077, -26198,
 -26318, -26437, -26556, -26673, -26789, -26905, -27019, -27132,
 -27244, -27355, -27466, -27575, -27683, -27790, -27896, -28001,
 -28105, -28208, -28309, -28410, -28510, -28608, -28706, -28802,
 -28897, -28992, -29085, -29177, -29268, -29358, -29446, -29534,
 -29621, -29706, -29790, -29873, -29955, -30036, -30116, -30195,
 -30272, -30349, -30424, -30498, -30571, -30643, -30713, -30783,
 -30851, -30918, -30984, -31049, -31113, -31175, -31236, -31297,
 -31356, -31413, -31470, -31525, -31580, -31633, -31684, -31735,
 -31785, -31833, -31880, -31926, -31970, -32014, -32056, -32097,
 -32137, -32176, -32213, -32249, -32284, -32318, -32350, -32382,
 -32412, -32441, -32468, -32495, -32520, -32544, -32567, -32588,
 -32609, -32628, -32646, -32662, -32678, -32692, -32705, -32717,
 -32727, -32736, -32744, -32751, -32757, -32761, -32764, -32766,
 -32767, -32766, -32764, -32761, -32757, -32751, -32744, -32736,
 -32727, -32717, -32705, -32692, -32678, -32662, -32646, -32628,
 -32609, -32588, -32567, -32544, -32520, -32495, -32468, -32441,
 -32412, -32382, -32350, -32318, -32284, -32249, -32213, -32176,
 -32137, -32097, -32056, -32014, -31970, -31926, -31880, -31833,
 -31785, -31735, -31684, -31633, -31580, -31525, -31470, -31413,
 -31356, -31297, -31236, -31175, -31113, -31049, -30984, -30918,
 -30851, -30783, -30713, -30643, -30571, -30498, -30424, -30349,
 -30272, -30195, -30116, -30036, -29955, -29873, -29790, -29706,
 -29621, -29534, -29446, -29358, -29268, -29177, -29085, -28992,
 -28897, -28802, -28706, -28608, -28510, -28410, -28309, -28208,
 -28105, -28001, -27896, -27790, -27683, -27575, -27466, -27355,
 -27244, -27132, -27019, -26905, -26789, -26673, -26556, -26437,
 -26318, -26198, -26077, -25954, -25831, -25707, -25582, -25456,
 -25329, -25201, -25072, -24942, -24811, -24679, -24546, -24413,
 -24278, -24143, -24006, -23869, -23731, -23592, -23452, -23311,
 -23169, -23027, -22883, -22739, -22594, -22448, -22301, -22153,
 -22004, -21855, -21705, -21554, -21402, -21249, -21096, -20942,
 -20787, -20631, -20474, -20317, -20159, -20000, -19840, -19680,
 -19519, -19357, -19194, -19031, -18867, -18702, -18537, -18371,
 -18204, -18036, -17868, -17699, -17530, -17360, -17189, -17017,
 -16845, -16672, -16499, -16325, -16150, -15975, -15799, -15623,
 -15446, -15268, -15090, -14911, -14732, -14552, -14372, -14191,
 -14009, -13827, -13645, -13462, -13278, -13094, -12909, -12724,
 -12539, -12353, -12166, -11980, -11792, -11604, -11416, -11227,
 -11038, -10849, -10659, -10469, -10278, -10087,  -9895,  -9703,
  -9511,  -9319,  -9126,  -8932,  -8739,  -8545,  -8351,  -8156,
  -7961,  -7766,  -7571,  -7375,  -7179,  -6982,  -6786,  -6589,
  -6392,  -6195,  -5997,  -5799,  -5601,  -5403,  -5205,  -5006,
  -4807,  -4608,  -4409,  -4210,  -4011,  -3811,  -3611,  -3411,
  -3211,  -3011,  -2811,  -2610,  -2410,  -2209,  -2009,  -1808,
  -1607,  -1406,  -1206,  -1005,   -804,   -603,   -402,   -201,
};

#if N_LOUD != 100
        ERROR: N_LOUD != 100
#endif

fixed Loudampl[100] = {
  32767,  29203,  26027,  23197,  20674,  18426,  16422,  14636,
  13044,  11626,  10361,   9234,   8230,   7335,   6537,   5826,
   5193,   4628,   4125,   3676,   3276,   2920,   2602,   2319,
   2067,   1842,   1642,   1463,   1304,   1162,   1036,    923,
    823,    733,    653,    582,    519,    462,    412,    367,
    327,    292,    260,    231,    206,    184,    164,    146,
    130,    116,    103,     92,     82,     73,     65,     58,
     51,     46,     41,     36,     32,     29,     26,     23,
     20,     18,     16,     14,     13,     11,     10,      9,
      8,      7,      6,      5,      5,      4,      4,      3,
      3,      2,      2,      2,      2,      1,      1,      1,
      1,      1,      1,      0,      0,      0,      0,      0,
      0,      0,      0,      0,
};


/*

#include        <stdio.h>
#include        <math.h>

#define M       4
#define N       (1<<M)

main(){
  fixed real[N], imag[N];
  int i;

  for (i=0; i<N; i++){
    //real[i] = 1000*cos(i*2*3.1415926535/N);
    real[i] = i;
    imag[i] = 0;
  }

  fix_fft(real, imag, M, 0);

  for (i=0; i<N; i++)
    printf("%d: %d, %d\n", i, real[i], imag[i]);

  fix_fft(real, imag, M, 1);

  for (i=0; i<N; i++)
     printf("%d: %d, %d\n", i, real[i], imag[i]);
  }
}

*/


