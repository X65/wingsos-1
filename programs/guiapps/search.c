#include <winlib.h>
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <wgslib.h>
#include <stdlib.h>

void *txtbar, *display, *mainwin;
char *param;

void beginsearch();
void search();

void quitapp() {
  exit(1);
}

void main(int argc, char * argv[]) {
  void *appl, *searchbut, *exitbut;
  int ch = 0;

  appl    = JAppInit(NULL,0);

  mainwin = JWndInit(NULL, NULL, 0, "Search", JWndF_Resizable);
  JWinSize(mainwin, 200, 100);  

  display = JTxtInit(NULL, mainwin, 0, "");
  JWinGeom(display, 0, 16, 0, 0, GEOM_TopLeft | GEOM_BotRight2);

  txtbar    = JTxfInit(NULL, mainwin, 0, "");
  JWinGeom(txtbar, 0, 0, 56, 16, GEOM_TopLeft | GEOM_TopRight2);

  searchbut = JButInit(NULL, mainwin, 0, "Search"); 
  JWinMove(searchbut, 56, 0, GEOM_TopRight);
  JWinOveride(searchbut, MJBut_Clicked, beginsearch);  

  exitbut = JButInit(NULL, mainwin, 0, "Exit"); 
  JWinMove(exitbut, 24, 0, GEOM_TopRight);
  JWinOveride(exitbut, MJBut_Clicked, quitapp);  

  JAppSetMain(appl, mainwin);
  JWinShow(mainwin);
  JAppLoop(appl);
  
} 

void beginsearch() {

  JWinKill(display);
  display = JTxtInit(NULL, mainwin, 0, "");
  JWinGeom(display, 0, 16, 0, 0, GEOM_TopLeft | GEOM_BotRight2);
  JWinShow(display);

  param = (char *)malloc(strlen(JTxfGetText(txtbar)));
  if(param == NULL)
    exit(1);
  strcpy(param, JTxfGetText(txtbar));
  if(strlen(JTxfGetText(txtbar)) < 1) {
    JWinSetPen(display, COL_Blue);
    JTxtAppend(display, "You must enter a search parameter.\n");
    JWinSetPen(display, COL_Black);
  } else {
    search("/wings/");
    JWinSetPen(display, COL_Blue);
    JTxtAppend(display, "Search Complete\n");
    JWinSetPen(display, COL_Black);
  }
  free(param);
  param = NULL;
}

void search(char * dirpath) {
  DIR *dir;
  struct dirent *entry;
  struct stat buf;
  char * fullname = NULL;
  char * nextdir = NULL;

  dir = opendir(dirpath);
  
  while(entry = readdir(dir)) {
    if(strstr(entry->d_name, param)) {
      JTxtAppend(display, dirpath);
      JTxtAppend(display, entry->d_name);
      JTxtAppend(display, "\n");
    }

    if(entry->d_type == 6) {
      nextdir = (char *)malloc(strlen(dirpath) + strlen(entry->d_name) +3);

      if(nextdir == NULL) 
        exit(1);

      sprintf(nextdir, "%s%s/", dirpath, entry->d_name);
      search(nextdir);
      free(nextdir);
      nextdir = NULL;
    }
  }
  closedir(dir);
}
