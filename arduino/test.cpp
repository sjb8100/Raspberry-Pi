#include <stdio.h>
#include "wstring.h"

int main (void) {
   char like[] = "I like coffee and cake"; // create a string

   // (1) print the string
   printf(like);
   printf("\n");
   // (2) delete part of the string
   like[13] = 0;
  printf(like);
  printf("\n");
   // (3) substitute a word into the string
   like[13] = ' '; // replace the null terminator with a space
   like[18] = 't'; // insert the new word
   like[19] = 'e';
   like[20] = 'a';
   like[21] = 0; // terminate the string
   printf(like);
   printf("\n");

   while (1){}
   return 0;
}