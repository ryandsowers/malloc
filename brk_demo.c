#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

void *set_brk(void *new_brk);
void *get_brk();
void *l_malloc(size_t size);
void l_free(void *ptr);

void *grow_brk(size_t sz) {
   return set_brk(get_brk() + sz);
}

int main() {
   char buf[1000];
   char *current = get_brk();
   snprintf(buf, sizeof(buf), "Current break: %p\n", current);
   write(1, buf, strlen(buf));

   char *my_mem = l_malloc(131024);     //test malloc functionality for exact heap availability
   snprintf(buf, sizeof(buf), "Your memory location of 131024: %p\n", my_mem);
   write(1, buf, strlen(buf));

   char *my_mem1 = l_malloc(16);        //test malloc functionality for heap extension
   snprintf(buf, sizeof(buf), "Your memory location of 16: %p\n", my_mem1);
   write(1, buf, strlen(buf));
  
   char *my_mem2 = l_malloc(10);        //test malloc functionality for small request
   snprintf(buf, sizeof(buf), "Your memory location of 10: %p\n", my_mem2);
   write(1, buf, strlen(buf));

   char *my_mem3 = l_malloc(2000);      //test malloc functionality for large request
   snprintf(buf, sizeof(buf), "Your memory location of 2000: %p\n", my_mem3);
   write(1, buf, strlen(buf));


   l_free(my_mem2);
   snprintf(buf, sizeof(buf), "Memory location freed: %p\n", my_mem2);
   write(1, buf, strlen(buf));

   l_free(my_mem1);
   snprintf(buf, sizeof(buf), "Memory location freed: %p\n", my_mem1);
   write(1, buf, strlen(buf));

   l_free(my_mem);
   snprintf(buf, sizeof(buf), "Memory location freed: %p\n", my_mem);
   write(1, buf, strlen(buf));

   l_free(my_mem3);
   snprintf(buf, sizeof(buf), "Memory location freed: %p\n", my_mem3);
   write(1, buf, strlen(buf));



   //now increase break by 128k
   // char *endp = set_brk(current + 0x20000);
   // snprintf(buf, sizeof(buf), "New break: %p\n", endp);
   // write(1, buf, strlen(buf));


   // snprintf(buf, sizeof(buf), "The range: %p-%p is now R/W\n", current, endp);
   // write(1, buf, strlen(buf));
   
   // endp = grow_brk(0x20000);

   // snprintf(buf, sizeof(buf), "New break: %p\n", endp);
   // write(1, buf, strlen(buf));

   // snprintf(buf, sizeof(buf), "The range: %p-%p is now R/W\n", current, endp);
   // write(1, buf, strlen(buf));
}
