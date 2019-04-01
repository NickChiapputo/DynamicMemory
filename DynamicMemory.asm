.text
	main:
		# Main program loops here. Input command is retrieved and parsed.
		# Based on input, memory is allocated, deallocated, or loop is restarted
		inputLoop:
			# Prompt for command
			li 			$v0, 4						# Load print_string command
			la 			$a0, CommandRequest 		# Give command request to user
			syscall

			la 			$a0, Input					# Load address of input string
			syscall									# Print input string


			# Read command
			li 			$v0, 8						# Load read_string command
			la 			$a0, UserString				# Put buffer address in $a0
			addi 		$a1, $zero, 12 				# Read a maximum of 12 characters (deallocate = 10 + '\n' + '\0')
			syscall									# User command will be stored in $a0
			jal 		removeNewLine				# Remove trailing newline from input


			# Compare input string and "allocate"
			la 			$a1, Allocate 				# Load address of Allocate in $a1
			jal 		strcmp


			# Check if user string matches allocate (i.e., $v0 = 1)
			addi 		$t0, $zero, 1
			beq 		$v0, $t0, allocateMemory


			# If user string does not match allocate, compare with "deallocate"
			la 			$a1, Deallocate 			# Load address of Deallocate in $a1
			jal 		strcmp


			# Check if user string matches deallocate (i.e., $v0 = 1)
			addi 		$t0, $zero, 1
			beq 		$v0, $t0, deallocateMemory


			# If user string does not match deallocate, compare with "quit"
			la 			$a1, Quit
			jal			strcmp


			# Check if user string matches quit (i.e., $v0 = 1)
			addi 		$t0, $zero, 1
			beq 		$v0, $t0, exit


			# If return value is zero, tell user the input was bad
			bne 		$v0, $zero, inputLoop
			li 			$v0, 4
			la 			$a0, BadInput
			syscall

			j 			inputLoop 					# Repeat input loop


		# Terminates execution
		exit:
			# Tell user program is done
			li 			$v0, 4
			la 			$a0, Stop
			syscall

			# Execute syscall 10 to terminate execution
			li 			$v0, 10
			syscall


	# #
	# Allocate New Memory
	#
	# This subroutine first gets the desired data size from the user.
	# It then checks to ensure that there is enough space in free memory
	# of contiguous space to store this amount of data.
	#
	# If there is enough space, the subroutine then gets the variable name
	# from the user. It then checks to ensure that this name is not taken.
	# If the name is taken, it will ask for another name until a valid one is given.
	#
	# The subroutine will then store the data and return to the input loop in main.
	#
	# In the loop, saved variables are:
	#	$s0 - Number of chunks to allocate
	#	$s1 - Index of first chunk (0 based)
	#	$s2 - Address of first character in string
	# #
	allocateMemory:
		# Prompt user for allocation size
		li 				$v0, 4						# Load print_string command
		la 				$a0, SizePrompt				# Load address of SizePrompt string
		syscall

		
		# Get user input for allocation size
		li 				$v0, 5						# Load read_int command
		syscall


		# Get number of chunks required
		xor 			$t0, $t0, $t0 				# Set initial number of chunks to zero
		addi 			$t1, $v0, 0					# Store allocation size in $t1 to free $v0

		chunks:
			addi 		$t1, $t1, -32				# Decrease current size by 32
			addi 		$t0, $t0, 1					# Increment number of chunks needed
			bgt 		$t1, $zero, chunks 			# Continue loop while current size is greater than zero

		add 			$s0, $t0, $zero 			# Save number of chunks in $s0	


		# Search for available contiguous space
		la 				$a1, ChunkList 				# Load address of the data table
		lw 				$t0, ($a1)					# Load first value
		xor				$t1, $t1, $t1 				# Initialize index to zero
		addi 			$t2, $zero, 64				# Set max index value
		xor				$t3, $t3, $t3 				# Initialize start index to zero
		xor				$t4, $t4, $t4 				# Initialize contiguous empty memory count to zero

		searchForSpace:
			li 			$v0, 1						# Load print_int command
			add 		$a0, $t1, $zero 			# Store index to print 
			syscall

			li 			$v0, 4						# Load print_string command
			la 			$a0, Dash					# Load address of " - " string
			syscall

			lw 			$a0, ($a1) 					# Load current value
			li 			$v0, 1 						# Load print_int command
			syscall 								# Pint current chunk value


			bne 		$a0, $zero, resetSearch		# If current value is not zero. reset counter and address start

			addi 		$t4, $t4, 1 				# Increment contiguous count
			beq 		$t4, $s0, endSearchForSpace	# Break out of loop if enough contiguous spaces have been found
			j 			skipReset 					# Avoid resetting the values

			resetSearch:
			addi 		$t3, $t1, 1 				# Reset start index to the next index
			xor 		$t4, $t4, $t4 				# Reset contiguous count

			skipReset:

			# Print newline
			li 			$v0, 4
			la 			$a0, NewLine
			syscall

			addi 		$a1, $a1, 4 				# Increment address by 4 bytes (size of integer)
			addi 		$t1, $t1, 1 				# Increment index by 1

			bne 		$t1, $t2, searchForSpace
		endSearchForSpace:  

#################################################################################################################

		# Find first empty string location and save address in $a0
		la 				$a0, VarNames 				# Load initial address of strings

		searchForAddress:



		# Get string from user. Address is in $a0
		addi 			$a1, $zero, 21				# Max length of string is 21 (20 characters + '\0')
		li 				$v0, 8						# Load read_string command
		syscall										# Read string
		jal 			removeNewLine 				# Remove trailing newline

#################################################################################################################

		j 				inputLoop 					# Restart the input loop

	deallocateMemory:
		li 				$v0, 4
		la 				$a0, Deallocate
		syscall


		j 				inputLoop 					# Restart the input loop


	# #
	# Remove newline function
	#	$a0 = string address
	#	$a1 = max string length
	#
	# This subroutine loops through the given string.
	# If the current char is not a null-terminator, repeat the loop.
	# 
	# If the current character is a null-terminator and the current index is equal 
	# to the maximum string length, then do not remove anything since the newline
	# does not exist.
	#
	# If the current character is a null-terminator and the current index is not
	# equal to the maximum string length, go back two indices (to the index of the newline)
	# and replace the newline character with a null-terminator
	# #
	removeNewLine:
		xor 			$t0, $a0, $zero 				# Set $t0 to string address
		xor 			$t1, $t1, $t1					# Set counter to zero

		remove:
			lbu 		$t2, ($t0)						# Get character in string
			addiu 		$t0, $t0, 1						# Increment pointer
			bne 		$t2, $zero, remove 				# Keep looping until null-terminator found
			beq 		$a1, $a2, skip 					# Check if string has been completely read
			addiu 		$t0, $t0, -2 					# Move back past null-terminator to newline index
			sb 			$zero, ($t0)					# Insert null-terminator where null-terminator was

		skip:
			jr 			$ra


	# #
	# String compare function							
	# 	$a0 = str1 (user string)
	#	$a1 = str2 (constant string)
	# 	$v0 = return value (0 = not equal, 1 = equal)	
	#													
	# C equivalent function:							
	#													
	#	int strcmp( char* a, char* b )					
	# 	{
	#		while( a != 0 )
	#		{
	#			if( a != b ) return 0;
	#		}
	#
	#		return 1;
	#	}
	# #
	strcmp:
		move 			$t0, $a0					# Save str1 in temp variable
		move 			$t1, $a1					# Save str2 in temp variable

		# Loop until end of str1 is found (equal result) or current chars are not equal (not equal result)
		loop:
			lbu			$t2, ($t0)					# Get next character from str1
			lbu			$t3, ($t1)					# Get next character from str2

			addi 		$t0, $t0, 1 				# Increment str1 pointer
			addi 		$t1, $t1, 1 				# Increment str2 pointer

			beq 		$t2, $zero, equal 			# If at end of string, strings are equal
			bne 		$t2, $t3, notEqual			# Compare characters from both strings

			j 			loop						# Restart the loop


		# str1 != str2
		notEqual:
			move 		$v0, $zero					# Set return value to 0
			jr 			$ra

		# str1 == str2
		equal:
			addi 		$v0, $zero, 1				# Set return value to 1
			jr 			$ra

.data
	Dash:				.asciiz " - "
	Quit:				.asciiz "quit"
	Stop:				.asciiz "End of Program."
	Input: 				.asciiz ">> "	
	NewLine:			.asciiz "\n"
	Allocate: 			.asciiz "allocate"
	NumChunks:			.asciiz "Number of chunks needed: "
	BadInput: 			.asciiz "Invalid command.\n\n"
	Deallocate: 		.asciiz "deallocate"
	NamePrompt: 		.asciiz "Variable Name\n>> "
	SizePrompt: 		.asciiz "Size to allocate\n>> "
	CommandRequest: 	.asciiz "Menu:\n\tAllocate\n\tDeallocate\n\tQuit\n"

	# Holds the user command string and variable name input
	UserString: 		.space 11

	# Holds user-defined variable names (64 names x 21 max size = 1344 bytes)
	# Max size of 21 = 20 characters + '\0'
	VarNames:			.space 1344

	# This shows the data table for all 64 chunks of data
	ChunkList: 			.word	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64