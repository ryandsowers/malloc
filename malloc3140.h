
#ifndef __MALLOC_3140_H
#define __MALLOC_3140_H

//allocate a block of memory capable of holding size
//bytes of user specified data. If size is zero, a pointer
//to zero bytes of memory should be returned
//returns NULL on failure or pointer to new block on success.
//Must never return a pointer to a block of memory that is
//already in use by the program (ie previously malloc'ed but
//not yet free)
//Operates in O(n) time.
//size_t is an unsigned 64-bit integer type
void *l_malloc(size_t size);

//release the memory pointed to by ptr. ptr may be NULL in which
//case no action is taken. Operates in O(1) time.
void l_free(void *ptr);

#endif
