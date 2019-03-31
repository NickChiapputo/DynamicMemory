.data
	CommandRequest: .asciiz "Menu:\n\tAllocate\n\tDeallocate\n\tQuit\n"
	Input: 			.asciiz ">> "	
	Allocate: 		.asciiz "allocate"
	Deallocate: 	.asciiz "deallocate"
	Quit:			.asciiz "quit"
	BadInput: 		.asciiz ""
	SizePrompt: 	.asciiz "Size to allocate\n>> "
	NamePrompt: 	.asciiz "Variable Name\n>> "
	Stop:			.asciiz "End of Program."

	# Holds the user command string
	UserString: .space 40

.text
	main:
		inputLoop:
			# Prompt for command
			li 		$v0, 4				# Load print_string command
			la 		$a0, CommandRequest # Give command request to user
			syscall

			la 		$a0, Input			# Load address of input string
			syscall						# Print input string

			la 		$a0, UserString		# Put buffer address in $a0
			la 		$a1, Allocate 		# Load address of Allocate in $a1

			# Read command
			li 		$v0, 8				# Load read_string command
			syscall						# User command will be stored in $a0

			# Compare input string and "allocate"
			jal 	strcmp

			# Check if user string mathes allocate (i.e., $v0 = 1)
			addi 	$t0, $zero, 1
			beq 	$v0, $t0, allocateMemory

			# If user string does not match allocate, compare with "deallocate"
			la 		$a1, Deallocate 	# Load address of Deallocate in $a1
			jal 	strcmp

			# Check if user string matches deallocate (i.e., $v0 = 1)
			addi 	$t0, $zero, 1
			beq 	$v0, $t0, deallocateMemory

			# If return value is zero, tell user the input was bad
			bne 	$v0, $zero, inputLoop
			li $v0, 4
			la $a0, 
			j 		inputLoop 	

		exit:

		# Tell user program is done
		li 		$v0, 4
		la 		$a0, Stop
		syscall

		# Execute syscall 10 to terminate execution
		li 		$v0, 10
		syscall


	# #
	#	
	# #
	allocateMemory:
		li $v0, 4
		la $a0, Allocate
		syscall

		jr $ra

	deallocateMemory:
		li $v0, 4
		la $a0, Deallocate
		syscall

		jr $ra

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
	#		while( a != '\n' )
	#		{
	#			if( a != b ) return 0;
	#		}
	#
	#		return 1;
	#	}
	# #
	strcmp:
		move $t0, $a0					# Save str1 in temp variable
		move $t1, $a1					# Save str2 in temp variable

		li $t4, 10						# Save line feed value 

		# Loop until end of str1 is found (equal result) or current chars are not equal (not equal result)
		loop:
			lb 		$t2, ($t0)			# Get next character from str1
			lb 		$t3, ($t1)			# Get next character from str2

			addi 	$t0, $t0, 1 		# Increment str1 pointer
			addi 	$t1, $t1, 1 		# Increment str2 pointer

			beq 	$t2, $t4, equal 	# If at end of string, strings are equal
			bne 	$t2, $t3, notEqual	# Compare characters from both strings

			j loop						# Restart the loop


		# str1 != str2
		notEqual:
			move 	$v0, $zero			# Set return value to 0
			jr $ra

		# str1 == str2
		equal:
			addi 	$v0, $zero, 1		# Set return value to 1
			jr $ra
