# THIS FILE IS THE PROPERTY OF DARIUS HODAEI
##############################################################################################

writecache:

    la $v0, ($ra) # preserve return address
    jal preserve # conventional to save registers
    la $ra, ($v0)

writec:
    la $s0, tag1
    addu $s1, $s0, $zero # moving the address
    addu $s4, $s0, $zero # duplicate address here
    li $s6, 0xfffffff0 #mask
    and $s5, $a0, $s6 # $s5 has correct tag after 'anding' address with mask
    li $s6, 0 # counter to 0
    li $s3, 0
    la $v0, valid1 # load valid address
    addu $k0, $v0, $zero
##############################################################################################

findaddress:
    lw $s2, ($s1)
    bne $s2, $s5, notfound # comparing whats in address tag with address calculated using mask
    lbu $v1, ($v0) # check valid bit to see if line is valid
    bne $v1, $zero, found

notfound:
    add $t8, $a0, $zero # save original address passed from row-major
    add $t9, $v0, $zero # save current contents of $v0
    la $a0, miss # set string address
    li $v0, 4 # print code
    syscall # print it

    add $a0, $t8, $zero # restore original address
    add $v0, $t9, $zero # restore value in $v0
    li $t8, 0 # erase $t8
    li $t9, 0 # erase $t9

    addi $s3, $s3, 32 # 32 bytes across each cache line so add this to get to next line
    addu $s1, $s4, $s3 # advance to next line in cache aswell
    addu $v0, $k0, $s3 # advance to next line in cache aswell
    addi $s6, $s6, 1 # increment counter
    bne $s6, $s7, findaddress
    # address not found so drops out loop after checking every line
##############################################################################################

validcheck:
    #check valid bit for a free space in the cache
    addu $v0, $k0, $zero #copy first valid address to $v0
    lw $v1, ($v0)
    li $s6, 0 # reset counter
    add $s1, $s4, $zero # load address of first cache line back in
   
    li $s3, 32 # restore value needed to move to next line in to $s3

validcheckloop:
    beqz $v1, foundvalid # found free space
    add $v0, $v0, $s3 #advance to next line of cache
    lw $v1, ($v0) # load value from $v0 address
    add $s1, $s1, $s3 # advance to next line of cache
    add $s6, $s6, 1 # increment counter
    bne $s6, $s7, validcheckloop # loop again whilst haven't checked all entries
   
    # if no free space found will drop straight through to evicting line
   
    add $s6, $a0, $zero # preserve original address before syscall
    add $v1, $a1, $zero # preserve original contents of $a1

    li $a1, 8 # set seed for random number generator
    li $v0, 42
    syscall


    add $t9, $v0, $zero # save current contents of $v0
    add $t8, $a0, $zero # save original address passed from row-major
    li $v0, 4 # print string code
    la $a0, eviction # set string address
    syscall # print it

    addi $a0, $t8, 1 # restore random number generated and add 1 because indexing is from 0-7, but we have rows named 1-8!
    li $v0, 1 # print integer code
    syscall

    li $v0, 4 # print string code
    la $a0, newline # new line character
    syscall

    add $a0, $t8, $zero # restore original value
    add $v0, $t9, $zero # restore value in $v0
    li $t8, 0 # erase $t8
    li $t9, 0 # erase $t9

    add $a1, $v1, $zero # restore $a1's value after syscall

    mult $s3, $a0 # multiply 32 by random number to get line of cache to evict
    mflo $a0 # move result of multiplication to $a0

    add $s1, $s0, $a0 # move to correct line as $s0 has tag1 address

    add $a0, $s6, $zero # restore original address

    lw $v0, 4($s1) # load value of dirty bit for checking
    beqz $v0, evictend # if data is not dirty, just chuck it out without saving to main memory

    add $s0, $s1 , 12 # move $s0 to start of data block for this line
   
    li $s6, 4 # counter for 4 words to store

    la $s5, ($ra) # preserve return address for jal
    jal evict
    la $ra, ($s5) # load return address back in

    j writec # jump back as space has been created now for new entry
##############################################################################################
# This sub-routine the values back to their correct position in main memory
# isolate evict routine so can be used by flush too, code reuse.

evict:   
    sub $s3, $s0, $s1 # difference between the address of data block and start of line
    sub $s3, $s3, 12 # minus 12 to account for 3 words before data block = offset
   
    lw $v0, ($s1) # load tag to $v0
   
    add $v0, $v0, $s3 # add tag to offset to get original address
    lw $v1, ($s0) # get contents of data byte pointed to by $s0
    sw $v1, ($v0) # store word from data block to main memory
    add $s0, $s0, 4 # move to next word in data block
    addi $s6, $s6, -1 # decrement counter
    bnez $s6, evict # loop

evictend:

    sw $zero, 4($s1) # set dirty byte to 0
    sw $zero, 8($s1) # valid bit is 2 words on from tag in the line
   
    jr $ra
##############################################################################################

foundvalid:
    add $s6, $v0, -4 # the word before the valid address is this lines dirty byte

    # store address tag in $s5 etc.
    sw $s5, ($s1) # store new tag address in free entry space
   
    # calculate offset
    li $s5, 15 # load 15 here to use when calculating offset

    lw $s5, ($a0) # load word stored at calculated offset address
    addi $s1, $s1, 12 # move to data block
    #sw  $a0, ($s5) # store what is in memory into start of data block
    sw  $s5, ($s1) # store what is in memory into start of data block

    # line won't be valid with only 1 byte so have to load 3 more before setting valid bit
    li $v0, 3 # counter for 0's needed to be stored to fill data block
    li $s3, 0 # load 0 value in that will be stored

fillentry:   
    addi $s1, $s1, 4 # move to next word in data block
    sw $s3, ($s1) # fill next byte with 0 in data block
    addi $v0, $v0, -1 # decrement counter
    bnez $v0, fillentry

    addi $s6, $s6, 4 # $s6 pointed to dirty byte so advance 4 to valid address for line
    li $s3, 1 # load 1 value to set valid bit
    sw $s3, ($s6) # set valid bit to 1

    j writec
##############################################################################################

found:
    add $t8, $a0, $zero # save original address passed from row-major
    add $t9, $v0, $zero # save current contents of $v0
    la $a0, hit # set string address
    li $v0, 4 # print code
    syscall # print it

    add $a0, $t8, $zero # restore original address
    add $v0, $t9, $zero # restore value in $v0
    li $t8, 0 # erase $t8
    li $t9, 0 # erase $t9

    li $s6, 15 # load 15 here to use when calculating offset
    and $s6, $s6, $a0 # gives offset to add to tag for finding original address
   
    lw $s0, ($s1) # load tag address
    add $s0, $s0, $s6 # add offset to tag address to get original address back
     
    lw $s5,($s0) # load data from main memory in to $s5
    addi $s6, $s6, 12 # move to datablock and add offset
    add $s1, $s1, $s6 # move pointer to correct position in datablock
    sw $s5, ($s1) # store new value at correct position in cache datablock
 
    sw $a1, ($s1) # store computed value in it's place
   
    li $s6, 1 # load 1 in to $v0
    sw $s6, -4($v0) # set dirty byte to 1
   
    j exit # jump to exit label

##############################################################################################

flushcache:
    add $t8, $a0, $zero # save original address passed from row-major
    add $t9, $v0, $zero # save current contents of $v0
    la $a0, flushed # set string address
    li $v0, 4 # print code
    syscall # print it

    add $a0, $t8, $zero # restore original address
    add $v0, $t9, $zero # restore value in $v0
    li $t9, 0 # erase $t9


    la $t8, ($ra) # preserve return address
    jal preserve # conventional to save registers
    la $ra, ($t8)

    li $t8, 0 # erase $t8

    la $a0, tag1
    li $a2, 0 # used for a counter, $s7 has number of cache lines in it already
    li $a3, 32 # used to skip to next cache entry

flushcheck:   
    lw $s4, 8($a0) # load valid byte value
    beqz  $s4, eraseline # it is not a valid entry so just erase it

flushline:
    lw $s4, 8($a0) # load valid byte value
    beqz  $s4, eraseline # if it is not dirty, just erase the line
   
    la $s4, ($ra) # preserve return address

    la $s1, ($a0) # parameter for sub-routine, start of the line
    add $s0, $s1, 12 # parameter for sub-routine, start of data block on line
    li $s6, 4 # parameter for sub-routine - counter for 4 words to store from data block
    jal evict

    la $ra, ($s4) # restore return address
  
eraseline:
    li $s5, 0 # counter for erasing a line
    add $a1, $a0, $zero # copy start of line address to $a1
eraseloop:
    sw $zero, ($a1) # store 0 value
    add $a1, $a1, 4 # move to next word in line
    addi $s5, $s5, 1 # increment word counter for this line
    bne $s5, $s7, eraseloop # there are 8 words to erase in a line

    add $a0, $a0, $a3 # move to start of next line
    add $a2, $a2, 1 # increment counter
    bne $a2, $s7, flushcheck   
	
    j exit

##############################################################################################
preserve:
  # OPTIMIZED. Originally saved all registers but upon inspecting which registers actually
  # have data in them at this point of every cycle, only a selection of registers needs preserving
	
	addi $sp, $sp, -44 # make space for all registers on stack
    	
	# store them in turn to the stack
	sw $a0, ($sp)
	sw $a1, 4($sp)
	sw $a2, 8($sp)
	sw $a3, 12($sp)
	sw $s0, 16($sp)
	sw $s1, 20($sp)
	sw $s2, 24($sp)
	sw $s7, 28($sp)
	sw $t0, 32($sp)
	sw $t1, 36($sp)
	sw $t2, 40($sp)
	
	jr $ra

##############################################################################################
exit:
  # OPTIMIZED. Originally restored all registers but upon inspecting which registers actually
  # required saving during every cycle, only a selection of registers need restoring
	
	# load them in turn from the stack
	lw $a0, ($sp)
	lw $a1, 4($sp)
	lw $a2, 8($sp)
	lw $a3, 12($sp)
	lw $s0, 16($sp)
	lw $s1, 20($sp)
	lw $s2, 24($sp)
	lw $s7, 28($sp)
	lw $t0, 32($sp)
	lw $t1, 36($sp)
	lw $t2, 40($sp)
	
	addi $sp, $sp, 44 # pop all items off the stack

	jr $ra

##############################################################################################
.data

#Space for fast associative write back CACHE memory 8 blocks * 4 words per block
tag1:    .word    0
dirty1:    .byte    0 : 4
valid1:    .byte    0 : 4
block1:    .word    0 : 4
space1: .word   0xffffffff
tag2:    .word    0
dirty2:    .byte    0 : 4
valid2:    .byte    0 : 4
block2:    .word    0 : 4
space2: .word   0xffffffff
tag3:    .word    0
dirty3:    .byte    0 : 4
valid3:    .byte    0 : 4
block3:    .word    0 : 4
space3: .word   0xffffffff
tag4:    .word    0
dirty4:    .byte    0 : 4
valid4:    .byte    0 : 4
block4:    .word    0 : 4
space4: .word   0xffffffff
tag5:    .word    0
dirty5:    .byte    0 : 4
valid5:    .byte    0 : 4
block5:    .word    0 : 4
space5: .word   0xffffffff
tag6:    .word    0
dirty6:    .byte    0 : 4
valid6:    .byte    0 : 4
block6:    .word    0 : 4
space6: .word   0xffffffff
tag7:    .word    0
dirty7:    .byte    0 : 4
valid7:    .byte    0 : 4
block7:    .word    0 : 4
space7: .word   0xffffffff
tag8:    .word    0
dirty8:    .byte    0 : 4
valid8:    .byte    0 : 4
block8:    .word    0 : 4
space8: .word   0xffffffff
# space1-8 is added but not used, just to make the cache fit right across the MARS display screen
#Main Memory
data:    .word     56058 : 256       # storage for 16x16 matrix of words
miss:		.asciiz	"MISS "
hit:		.asciiz	"HIT!\n"
eviction:	.asciiz	"\nCache Line chosen for eviction: "
newline:	.asciiz	"\n"
flushed:	.asciiz	"Flushing cache in preparation for end of program.\n"
