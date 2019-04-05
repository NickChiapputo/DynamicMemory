.text
	main:
		# Main program loops here. Input command is retrieved and parsed.
		# Based on input, memory is allocated, deallocated, or loop is restarted
		inputLoop:
			# Prompt for command
			li 			$v0, 4									# Load print_string command
			la 			$a0, CommandRequest 					# Give command request to user
			syscall

			la 			$a0, Input								# Load address of input string
			syscall												# Print input string


			# Read command
			li 			$v0, 8									# Load read_string command
			la 			$a0, UserString							# Put buffer address in $a0
			addi 		$a1, $zero, 12 							# Read a maximum of 12 characters (deallocate = 10 + '\n' + '\0')
			syscall												# User command will be stored in $a0
			jal 		removeNewLine							# Remove trailing newline from input


			la 			$a1, Allocate 							# Load address of Allocate in $a1
			jal 		strcmp									# Compare user string with "allocate"

			beq 		$v0, $zero, allocateMemory				# If user string matches allocate ($v0 = 0), jump to allocate subroutine


			la 			$a1, Deallocate 						# Load address of Deallocate in $a1
			jal 		strcmp									# Compare user string with "deallocate"

			beq 		$v0, $zero, deallocateMemory 			# If user string matches deallocate ($v0 = 0), jump to deallocate subroutine


			la 			$a1, Table 								# Load address of Table in $a1
			jal strcmp 											# Compare user string with "table"

			beq 		$v0, $zero, printTable 					# If user string matches table ($v0 = 0), jump to print table


			la 			$a1, Quit 								# Load address of Quit in $a1
			jal			strcmp									# Compare user string with "quit"

			beq 		$v0, $zero, exit 						# If user string matches quit, ($v0 = 0), jump to exit subroutine


			# If user string did not match "quit", then input is bad. 
			li 			$v0, 4									# Load print_string command
			la 			$a0, BadInput 							# Load address for BadInput string
			syscall												# Print BadInput string

			j 			inputLoop 								# Repeat input loop


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
	# 	$s3 - Index of first empty string for variable name
	# #
	allocateMemory:
		li 				$v0, 4									# Load print_string command
		la 				$a0, NewLine 							# Load address of NewLine string
		syscall

		# Prompt user for allocation size
		la 				$a0, SizePrompt							# Load address of SizePrompt string
		syscall

		
		# Get user input for allocation size
		li 				$v0, 5									# Load read_int command
		syscall 												# Read bytes to allocate from user


		bgt 			$v0, $zero, goodChunks 					# If valid number was entered, continue to goodChunks


		# If bad value entered, tell user input is bad and return to menu
		la 				$a0, BadChunkInput 						# Load address of BadChunkInput string
		li 				$v0, 4									# Load print_string command
		syscall													# Print BadChunkInput string

		la 				$a0, NewLine 							# Load address of NewLine string
		syscall
		syscall

		j inputLoop												# Return to main loop

		goodChunks:

		# Get number of chunks required
		xor 			$s0, $s0, $s0 							# Set initial number of chunks to zero
		addi 			$t1, $v0, 0								# Store allocation size in $t1 to free $v0

		chunks:
			addi 		$t1, $t1, -32							# Decrease current size by 32
			addi 		$s0, $s0, 1								# Increment number of chunks needed
			bgt 		$t1, $zero, chunks 						# Continue loop while current size is greater than zero	
		endChunks:


		# Search for available contiguous space
		la 				$a1, ChunkList 							# Load address of the data table
		xor				$t1, $t1, $t1 							# Initialize index to zero
		addi 			$t2, $zero, 64							# Set max index value
		xor				$s1, $s1, $s1 							# Initialize start index to zero
		xor				$t3, $t3, $t3 							# Initialize contiguous empty memory count to zero

		searchForSpace:
			lw 			$t0, ($a1)								# Load current value
			bne 		$t0, $zero, resetSearch					# If current value is not zero. reset counter and address start

			addi 		$t3, $t3, 1 							# Increment contiguous count
			beq 		$t3, $s0, endSearchForSpace				# Break out of loop if enough contiguous spaces have been found
			j 			skipReset 								# Avoid resetting the values

			resetSearch:
				addi 		$s1, $t1, 1 						# Reset start index to the next index
				xor 		$t3, $t3, $t3 						# Reset contiguous count

			skipReset:

			addi 		$a1, $a1, 4 							# Increment address by 4 bytes (size of integer)
			addi 		$t1, $t1, 1 							# Increment index by 1
			bne 		$t1, $t2, searchForSpace 				# If index is not equal to 64, continue looping


			# This will only run if index is equal to 64 in which case contiguous spaces are not found
			# Tell user allocation failed due to no space for a string
			li 			$v0, 4									# Load print_string command
			la 			$a0, NewLine 							# Load address of NewLine string
			syscall												# Print newline
			la 			$a0, NoChunkSpaceFail					# Load address of NoChunkSpaceFail string
			syscall												# Print chank space fail string
			la 			$a0, NewLine 							# Load address of NewLine string
			syscall												# Print newline
			syscall												# Print newline

			j inputLoop
		endSearchForSpace:  


		# Find first empty string location and save address in $s2
		la 				$s2, VarNames 							# Load first index
		xor 			$s3, $s3, $s3							# Initialize index to zero
		addi 			$t1, $zero, 64							# Initialize max index to 63 (64 total words)

		emptyStringSearch:
			lbu			$t2, ($s2) 							# Load first bit of string
			beq 		$t2, $zero, endEmptyStringSearch	# If first byte of string is 0, then string is empty

			addi 		$s2, $s2, 21						# Increment string by 21 bytes to next string
			addi 		$s3, $s3, 1							# Increment index by one
			blt 		$s3, $t1, emptyStringSearch 		# While index is less than max, keep looping
		endEmptyStringSearch:


		blt 			$s3, $t1, continueAllocate				# If index $s3 is less than 64, an empty string was found

		# If index is equal to 64, then a string was not found. Abandon allocation
		# Print newline
		la 				$a0, NewLine 							# Load address of NewLine string
		li 				$v0, 4									# Load print_string command
		syscall

		# Tell user allocation failed due to no space for a string
		la 				$a0, NoNameSpaceFail					# Load address of NoNameSpaceFail string
		li 				$v0, 4									# Load print_string command
		syscall
		la 				$a0, NewLine 							# Load newline
		syscall													# Print newline
		syscall													# Print newline

		j 				inputLoop


		continueAllocate:


		la 				$a0, NewLine 							# Load address of NewLine string
		li 				$v0, 4
		syscall


		# Prompt user for variable name
		la 				$a0, NamePrompt 						# Load address of NamePrompt string
		li 				$v0, 4									# Load print_string command
		syscall													# Print NamePrompt string


		# Get string from user. Address is in $a0
		addi 			$a1, $zero, 22							# Max length of string is 22 (20 characters + '\n' + '\0'). newline is then removed to make max length of 21
		addi 			$a0, $s2, 0 							# Set buffer address to address of first empty string
		li 				$v0, 8									# Load read_string command
		syscall													# Read string
		jal 			removeNewLine 							# Remove trailing newline


		addi 			$s2, $a0, 0 							# Store address of beginning of first empty string in $s2


		# Loop through variable name list and check if user given name already exists. User string is already in $a0
		la 				$a1, VarNames 							# Load address of the name table
		xor				$a2, $a2, $a2 							# Initialize index to zero
		addi 			$a3, $zero, 63							# Set max index value

		checkForDuplicate:
			bgt 		$a2, $a3, noDuplicate		 			# If index is greater than max index, exit loop
			beq 		$a2, $s3, skipCheck 					# If current index is equal to variable index, skip checking for duplicate

			lbu 		$t0, ($a1)								# Load first byte of current word in name table
			beq 		$t0, $zero, skipCheck 					# If first byte is null, no string exists. Skip checking to save computation time

			jal 		strcmp 									# Compare user variable name and current name from table

			beq 		$v0, $zero, endCheckForDuplicate 		# If return value is 0, strings match and a duplicate is found

			skipCheck:
			addi 		$a2, $a2, 1 							# Increment index
			addi 		$a1, $a1, 21 							# Increment variable name address to next word

			j 			checkForDuplicate
		endCheckForDuplicate:

		# Erase user variable name. $a0 already has address of variable name string
		addi 			$a1, $zero, 21 							# Set $a1 to length of string
		jal 			strdel									# Delete string (zeroes out bytes)


		# Tell user name already exists
		la 				$a0, BadVarName 						# Load address of BadVarName string
		li 				$v0, 4	 								# Load print_string command
		syscall 												# Print BadVarName string
		la 				$a0, NewLine 							# Load address of NewLine string
		syscall													# Print newline
		syscall 												# Print newline

		j inputLoop


		noDuplicate:
		# Edit the chunk table to save new chunk availabilities
		la 				$a0, ChunkList							# Load address of data table
		sll 			$t0, $s1, 2								# Multiply index of first int by four (each int takes four bytes)
		add 			$a0, $a0, $t0 							# Get address of first int to be saved

		xor 			$t0, $t0, $t0 							# Set initial number of chunks saved to zero. Max is stored in $s0
		addi 			$t1, $zero, 1 							# Set $t1 to 1. This will be stored in all chunks to be saved

		saveChunkData:
			sw 			$t1, ($a0)								# Store the value 1 in current chunk

			addi 		$t0, $t0, 1 							# Increment number of chunks saved
			addi 		$a0, $a0, 4								# Increment by four bytes to next chunk

			blt 		$t0, $s0, saveChunkData 				# Keep looping until number of chunks saved is equal to the number of chunks that are supposed to be allocated
		endSaveChunkData:


		# Save the number of chunks stored for this variable
		la 				$a0, ChunkCountList						# Load address of table for number of chunks allocated
		sll 			$t0, $s3, 2								# Multiply the variable index by four to get the byte offset
		add 			$a0, $a0, $t0 							# Get the full address of the current variable being allocated

		sw 				$s0, ($a0) 								# Store the number of chunks allocated


		# Save the index of the first chunk allocated for this variable
		la 				$a0, ChunkIndexList	 					# Load address of table for index of first chunk allocated
		add 			$a0, $a0, $t0 							# Get the full address of the current variable being allocated

		sw 				$s1, ($a0)								# Store the index of the first chunk allocated


		la 				$a0, NewLine 							# Load address of NewLine string
		li 				$v0, 4									# Load print_string command
		syscall													# Print newline
		syscall 												# Print newline


		# Print successful allocation message one
		la 				$a0, AllocateMessage1
		syscall


		# Print number of chunks
		li 				$v0, 1
		addi 			$a0, $s0, 0
		syscall


		# Print successful allocation message two
		li 				$v0, 4
		la 				$a0, AllocateMessage2
		syscall


		# Print variable name
		addi 			$a0, $s2, 0 							# Load address of first empty string in $s2
		syscall 												# Print variable name


		# Print newline
		li 				$v0, 4
		la 				$a0, NewLine
		syscall
		syscall


		j 				inputLoop 								# Restart the input loop


	# #
	# Deallocate Existing Memory
	#
	# This subroutine first gets a variable name from the user. It then
	# searches the variable name list for that name and, if it exists,
	# saves the index at which it was found. If not found, user is informed
	# and is returned to the main menu (inputLoop)
	#
	# Once the index is found, it will find the index of the first allocated chunk
	# and the number of chunks. First it will delete the chunks from the data table
	# by changing the values of the proper indices to 0. Then, it will delete the 
	# number of chunks in the ChunkCountList table by changing the value to 0. The
	# index of the first chunk will then be deleted from the ChunkIndexList by again
	# changing the value to 0. Finally, using the strdel routine, it will delete the 
	# variable name from the VarNames table. 
	#
	# The routine will then alert the user that deallocation has successfully occurred 
	# and will return to the main menu (inputLoop)
	#
	# In the loop, saved variables are:
	#	$s0 - Address of first character in the variable name in the VarNames table
	#	$s1 - Index of the first allocated chunk
	# 	$s2 - Number of chunks
	# 	$s3 - Address offset
	# #
	deallocateMemory:
		la 				$a0, NewLine 							# Load address of NewLine string
		li 				$v0, 4									# Load print_string command
		syscall													# Print newline


		la 				$a0, NamePrompt							# Load address of NamePrompt
		syscall 												# Print NamePrompt


		la 				$a0, UserString 						# Load address of UserString to hold variable name
		addi 			$a1, $zero, 22 							# Set max input length to 22 (string + '\n' + '\0')
		li 				$v0, 8 									# Load read_string command
		syscall 												# Read string from user

		jal 			removeNewLine 							# Remove trailing newline from input


		# Loop through variable name list and check if user given name exists. User string is already in $a0
		la 				$a1, VarNames 							# Load address of the name table
		xor				$a2, $a2, $a2 							# Initialize index to zero
		addi 			$a3, $zero, 63							# Set max index value

		lookForName:
			bgt 		$a2, $a3, endLookForName	 			# If index is greater than max index, exit loop

			lbu 		$t0, ($a1)								# Load first byte of current word in name table
			beq 		$t0, $zero, skipLook 					# If first byte is null, no string exists. Skip checking to save computation time

			jal 		strcmp 									# Compare user variable name and current name from table

			beq 		$v0, $zero, nameFound			 		# If return value is 0, strings match and a duplicate is found

			skipLook:
			addi 		$a2, $a2, 1 							# Increment index
			addi 		$a1, $a1, 21 							# Increment variable name address to next word

			j 			lookForName
		endLookForName:

		# This will only run if variable name is not found
		la 				$a0, BadVariable 						# Load address of BadVariable string
		li 				$v0, 4 									# Load print_string command
		syscall 												# Print BadVariable string

		la 				$a0, NewLine 							# Load address of NewLine
		syscall													# Print newline
		syscall													# Print newline

		j 				inputLoop 								# Restart the input loop

		nameFound:
		addi 			$s0, $a1, 0 							# Store string address in $s0
		sll 			$s3, $a2, 2								# Multiply the variable index by four to get the byte offset

		# Get index of first allocated chunk
		la 				$a0, ChunkIndexList	 					# Load address of table for index of first chunk allocated
		add 			$a0, $a0, $s3 							# Get the full address of the first chunk for the current variable
		lw 				$s1, ($a0)								# Get the index of the first allocated chunk	


		# Get number of data chunks allocated for this variable
		la 				$a0, ChunkCountList 					# Load address of table for number of chunks allocated
		add 			$a0, $a0, $s3 							# Get the full address of the number of chunks allocated for the current variable
		lw 				$s2, ($a0)


		# Erase data chunks
		la 				$a0, ChunkList 							# Load address of memory table
		sll 			$t0, $s1, 2 							# Get address offset by multiplying starting index by four bytes
		add 			$a0, $a0, $t0							# Get the full address of the first allocated chunk for the current variable
		xor 			$t0, $t0, $t0 							# Set initial index to zero

		eraseData:
			sw 			$zero, ($a0) 							# Empty current index of memory table by storing a zero
			addi 		$a0, $a0, 4 							# Increment to next data location
			addi 		$t0, $t0, 1 							# Increment index

			blt 		$t0, $s2, eraseData 					# Keep looping while current index is less than total number of chunks to be deallocated
		endEraseData:


		# Print successful deallocation messages. Must do before deleting rest of data so that it can be displayed to user
		la 				$a0, DeallocateMessage1 				# Load address of DeallocateMessage1
		addi 			$v0, $zero, 4 							# Load print_string command
		syscall 												# Print DeallocateMessage1

		addi 				$a0, $s0, 0 							# Load address of variable name to $a0
		syscall 												# Print variable name

		la 				$a0, DeallocateMessage2 				# Load address of DeallocateMessage2
		addi 			$v0, $zero, 4 							# Load print_string command
		syscall 												# Print DeallocateMessage2

		addi 			$a0, $s2, 0 							# Load number of chunks
		addi 			$v0, $zero, 1 							# Load print_int command
		syscall 												# Print number of chunk

		la 				$a0, DeallocateMessage3 				# Load address of DeallocateMessage3
		addi 			$v0, $zero, 4 							# Load print_string command
		syscall 												# Print DeallocateMessage3

		addi 			$a0, $s1, 0 							# Load starting index of chunks deleted
		addi 			$v0, $zero, 1 							# Load print_int command
		syscall 												# Print starting idnex of chunks deleted

		la 				$a0, DeallocateMessage4 				# Load address of DeallocateMessage4
		addi 			$v0, $zero, 4 							# Load print_string command
		syscall 												# Print DeallocateMessage4


		# Erase number of data chunks
		la 				$a0, ChunkCountList 					# Load address of table for number of chunks allocated
		add 			$a0, $a0, $s3 							# Get the full address of the number of chunks allocated for the current variable
		sw 				$zero, ($a0)							# Erase number of data chunks by storing zero in location


		# Erase index of first allocated chunk
		la 				$a0, ChunkIndexList 					# Load address of table for index of first chunk allocated
		add 			$a0, $a0, $s3 							# Get the full address of the index of first chunk allocated for the current variable
		sw 				$zero, ($a0)							# Erase index of first chunk by storing zero in location


		# Erase user variable name
		addi 			$a0, $s0, 0 							# Load address of variable name to $a0
		addi 			$a1, $zero, 21 							# Set $a1 to length of string
		jal 			strdel									# Delete string (zeroes out bytes)


		j 				inputLoop 								# Restart the input loop


	# #
	# Print table function
	#
	# This routine will simply print a table in the following format:
	# 
	#	INDEX - VAR_NAME - INDEX_OF_FIRST_CHUNK - NUM_CHUNKS
	#
	# C equivalent function:
	#
	# 	void printTable( char** names, int[] indices, int[] numChunks )
	#	{
	#		int i;
	#
	# 		puts( "+-------+----------------------+----------------+------------------+" );
	#		puts( "| Index |     Variable Name    | Starting Index | Number of Chunks |" );
	# 		puts( "+-------+----------------------+----------------+------------------+" );
	#
	#		for( i = 0; i < 64; i++ )
	#			printf( "| %2i    | %20s | %2i             | %2i               |\n", i, names[ i ], indices[ i ], numChunks[ i ] );
	# 		puts( "+-------+----------------------+----------------+------------------+" );
	#
	#		return;
	# 	}
	# #
	printTable:		
		la 				$a0, NewLine 							# Load address of NewLine
		li 				$v0, 4									# Load print_string command
		syscall													# Print newline

		la 				$a0, TableDivider 						# Load address of TableDivider string
		syscall 												# Print TableDivider

		la 				$a0, TableHeader 						# Load address of TableHeader string
		syscall 												# Print TableHeader

		la 				$a0, TableDivider 						# Load address of TableDivider string
		syscall 												# Print TableDivider

		# Print all data for TESTING in format INDEX - VAR_NAME - FIRST_CHUNK_INDEX - CHUNK_COUNT
		la 				$a1, VarNames
		la 				$a2, ChunkIndexList
		la 				$a3, ChunkCountList

		xor 			$t0, $t0, $t0 							# Set index to zero
		addi 			$t1, $zero, 64							# Set max index to 64

		printData:
			lbu 		$t2, ($a1) 								# Load first byte of current word
			beq 		$t2, $zero, skipPrint					# If current word is empty, skip print to save console space


			la 			$a0, TableLeftEdge 						# Load address of TableLeftEdge string
			addi 		$v0, $zero, 4 							# Load print_string command
			syscall 											# Print TableLeftEdge


			# Print index value with padding to form 5 spaces
			xor 		$t2, $t2, $t2 							# Set starting index to 0
			addi 		$t3, $zero, 2 							# Set maximum index initially to two
			addi 		$a0, $zero, 32 							# Load ASCII value for space (' ')
			addi 		$v0, $zero, 11 							# Load print_byte command

			bgt 		$t0, 9, printIndexSpaces 				# If the index is greater than nine, only three spaces are needed
			addi 		$t3, $t3, 1 							# If the index is less than ten, four spaces are needed

			printIndexSpaces:
				bgt 	$t2, $t3, endPrintIndexSpaces 			# Keep looping until index is greater than maximum index
				
				syscall 										# Print space
				
				addi 	$t2, $t2, 1 							# Increment index by 1
				
				j 		printIndexSpaces 						# Keep looping
			endPrintIndexSpaces:

			li 			$v0, 1									# Load print_int command
			addi 		$a0, $t0, 0								# Store current index in $a0
			syscall												# Print current index

			la 			$a0, TableBorder 						# Load address of TableBorder string
			li 			$v0, 4 									# Load print_string command
			syscall												# Print Dash string	


			# Print variable name with padding to form 20 spaces
			addi 		$t2, $a1, 0 							# Store string address in temp register $t2
			xor 		$t3, $t3, $t3 							# Set initial index to zero
			addi 		$v0, $zero, 11 							# Load print_byte command
			addi 		$t4, $zero, 20 							# Set max string length (20 = max length - '\0')

			printName:
				bge 	$t3, $t4, endPrintName 					# Keep looping until index is greater than max index

				lbu 	$a0, ($t2) 								# Load current byte

				bne 	$a0, $zero, skipSpace 					# If current byte is not null-terminator, don't print space

				addi 	$a0, $zero, 32 							# Load ASCII value of space (' ')

				skipSpace:

				syscall 										# Print current character (either character or space)

				addi 	$t2, $t2, 1 							# Increment address by 1 byte for next character
				addi 	$t3, $t3, 1 							# Increment index by 1

				j 		printName 								# Continue looping
			endPrintName:


			la 			$a0, TableBorder						# Load address of Dash string
			li 			$v0, 4 									# Load print_string command
			syscall												# Print Dash string


			# Print starting chunk index value with padding to form 13 spaces
			lw 			$t4, ($a2) 								# Load starting chunk index value
			xor 		$t2, $t2, $t2 							# Set starting index to 0
			addi 		$t3, $zero, 11 							# Set maximum index initially to 11
			addi 		$a0, $zero, 32 							# Load ASCII value for space (' ')
			addi 		$v0, $zero, 11 							# Load print_byte command

			bgt 		$t4, 9, printStartIndexSpaces 			# If the index is greater than nine, only three spaces are needed
			addi 		$t3, $t3, 1 							# If the index is less than ten, four spaces are needed

			printStartIndexSpaces:
				bgt 	$t2, $t3, endPrintStartIndexSpaces 		# Keep looping until index is greater than maximum index
				
				syscall 										# Print space
				
				addi 	$t2, $t2, 1 							# Increment index by 1
				
				j 		printStartIndexSpaces					# Keep looping
			endPrintStartIndexSpaces:

			addi 		$a0, $t4, 0								# Store current chunk index in $a0
			li 			$v0, 1									# Load print_int command
			syscall												# Print current index

			la 			$a0, TableBorder						# Load address of Dash string
			li 			$v0, 4 									# Load print_string command
			syscall												# Print Dash string


			# Print number of chunk with padding to form 13 spaces
			lw 			$t4, ($a3) 								# Load current chunk count value
			xor 		$t2, $t2, $t2 							# Set starting index to 0
			addi 		$t3, $zero, 13 							# Set maximum index initially to 13
			addi 		$a0, $zero, 32 							# Load ASCII value for space (' ')
			addi 		$v0, $zero, 11 							# Load print_byte command

			bgt 		$t4, 9, printNumChunkSpaces 			# If the index is greater than nine, only three spaces are needed
			addi 		$t3, $t3, 1 							# If the index is less than ten, four spaces are needed

			printNumChunkSpaces:
				bgt 	$t2, $t3, endPrintNumChunkSpaces 		# Keep looping until index is greater than maximum index
				
				syscall 										# Print space
				
				addi 	$t2, $t2, 1 							# Increment index by 1
				
				j 		printNumChunkSpaces						# Keep looping
			endPrintNumChunkSpaces:

			addi		$a0, $t4, 0								# Store current chunk count in $a0
			li 			$v0, 1									# Load print_int command
			syscall												# Print current index

			la 			$a0, TableRightEdge 					# Load address of TableRightEdge string
			li 			$v0, 4 									# Load print_string command
			syscall												# Print TableRightEdge

			skipPrint:

			addi 		$a1, $a1, 21 							# Increment current address to next variable name
			addi 		$a2, $a2, 4 							# Increment current address to next chunk index
			addi 		$a3, $a3, 4 							# Increment current address to next chunk count
			addi 		$t0, $t0, 1 							# Increment index

			blt 		$t0, $t1, printData 					# Keep looping while index is less than max index


			la 			$a0, TableDivider	 					# Load address of TableDivider string
			addi 		$v0, $zero, 4 							# Load print_string command
			syscall 											# Print TableDivider

			la 			$a0, NewLine 							# Load address of NewLine string
			syscall 											# Print newline
		endPrintData:

		j 				inputLoop								# Return to main menu


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
	# Case insensitive string compare function							
	# 	$a0 = str1 (user string)
	#	$a1 = str2 (constant string)
	# 	$v0 = return value (0 = equal, 1 = not equal)	
	#													
	# C equivalent function:							
	#													
	#	int strcmp( char* a, char* b )					
	# 	{
	#		while( 1 )
	#		{
	#			if( a > 64 && a < 91 ) a += 32;
	# 			if( b > 64 && b < 91 ) b += 32;
	#
	#			if( a != b ) return 1;
	#			else if( a == 0 ) return 0;
	#		}
	#
	#		return 0;
	#	}
	# #
	strcmp:
		move 			$t0, $a0					# Save str1 in temp variable
		move 			$t1, $a1					# Save str2 in temp variable

		# Loop until end of str1 is found (equal result) or current chars are not equal (not equal result)
		loop:
			lbu			$t2, ($t0)					# Get next character from str1
			lbu			$t3, ($t1)					# Get next character from str2

			# Set $t2 to lower case
			bgt 		$t2, 90, skipLowerCase1		# If ASCII value is above 90 ('Z'), character is already lower case
			blt 		$t2, 65, skipLowerCase1 	# If ASCII value is less than 65 ('A'), character case should not be changed
			addi 		$t2, $t2, 32 				# Flip case bit

			skipLowerCase1:

			# Set $t3 to lower case
			bgt 		$t3, 90, skipLowerCase2 	# If ASCII value is above 90 ('Z'), character is already lower case
			blt 		$t3, 65, skipLowerCase2 	# If ASCII value is less than 65 ('A'), character case should not be changed
			addi 		$t3, $t3, 32 				# Flip case bit 

			skipLowerCase2:


			addi 		$t0, $t0, 1 				# Increment str1 pointer
			addi 		$t1, $t1, 1 				# Increment str2 pointer

			bne 		$t2, $t3, notEqual			# Compare characters from both strings
			beq 		$t2, $zero, equal 			# If at end of string, strings are equal

			j 			loop						# Restart the loop


		# str1 != str2
		notEqual:
			addi  		$v0, $zero, 1				# Set return value to 1
			jr 			$ra 						# Return to caller

		# str1 == str2
		equal:
			xor 		$v0, $v0, $v0				# Set return value to 0
			jr 			$ra 						# Return to caller


	# #
	# String delete function
	# 	$a0 = str
	# 	$a1 = len
	#
	# This subroutine zeroes out the string in order to delete it.
	#
	# C equivalent function
	#
	# 	void strdel( char * a, int len )
	# 	{
	# 		int i = 0;
	#		
	# 		while( i <= len)
	# 			a++ = 0;
	#
	#		return;
	#	}
	# #
	strdel:
		xor 			$t0, $t0, $t0 							# Set starting index to zero

		deleteString:
			bge 		$t0, $a1, endDeleteString				# If index is greater than length of string, exit loop

			sb 			$zero, ($a0)							# Store zero at current address

			addi 		$t0, $t0, 1 							# Increment index
			addi 		$a0, $a0, 1								# Increment string address

			j deleteString
		endDeleteString:

		jr $ra

.data
	Dash:				.asciiz " - "																		# Used to format output
	Quit:				.asciiz "quit"																		# Used to compare with user input
	Stop:				.asciiz "\nEnd of Program."															# Tell user program has terminated
	Input: 				.asciiz ">> "																		# Prompts user for input
	Table: 				.asciiz "table"																		# Used to compare with user inptu
	NewLine:			.asciiz "\n"																		# newline character
	Allocate: 			.asciiz "allocate"																	# Used to compare with user input
	BadInput: 			.asciiz "Invalid command.\n\n"														# Tell user an invalid menu command was given
	BadVarName:			.asciiz "\nVariable name exists, allocation failed."								# FAIL case: given variable name for allocation exists in symbol table
	Deallocate: 		.asciiz "deallocate"																# Used to compare with user input
	NamePrompt: 		.asciiz "Variable Name\n>> "														# Prompt user for name of variable to allocate/deallocate
	SizePrompt: 		.asciiz "Bytes to allocate\n>> "													# Prompt user for number of bytes needed for variable
	BadVariable:		.asciiz "\nVariable not found in symbol table, unable to deallocate."				# FAIL case: User attempts to deallocate variable name that doesn't exist
	TableBorder: 		.asciiz " | " 																		# Used to format table output
	TableHeader:		.asciiz "| Index |     Variable Name    | Starting Index | Number of Chunks |\n" 	# Header string for table output
	TableDivider:		.asciiz "+-------+----------------------+----------------+------------------+\n" 	# Used to format table output
	BadChunkInput: 		.asciiz "Invalid byte size input. An integer value greater than 0 is required."		# FAIL case: User did not give positive integer number of bytes to allocate
	TableLeftEdge: 		.asciiz "| " 																		# Used for table formatting
	CommandRequest: 	.asciiz "Menu:\n\tAllocate\n\tDeallocate\n\tTable\n\tQuit\n"						# Formatted menu for user
	TableRightEdge:		.asciiz " |\n" 																		# Used for table formatting
	NoNameSpaceFail:	.asciiz "Not enough free memory, allocation failed."								# FAIL case: Attempted allocation with not enough memory to store variable name
	AllocateMessage1: 	.asciiz "Successfully allocated "													# First part of successful allocation message. Followed by number of chunks
	AllocateMessage2: 	.asciiz " chunk(s) for "															# Second part of successful allocation message. Followed by variable name
	NoChunkSpaceFail: 	.asciiz "Allocation failed due to no space for memory allocation."					# FAIL case: Attempted allocation with not enough memory to store required number of chunks
	DeallocateMessage1: .asciiz "Successfully deallocated " 												# First part of successful deallocation message. Followed by variable name
	DeallocateMessage2: .asciiz " and freed "																# Second part of successful deallocation message. Followed by number of chunks freed
	DeallocateMessage3: .asciiz " chunks starting at index " 												# Third part of successful deallocation message. Followed by starting index of freed chunks
	DeallocateMessage4: .asciiz ".\n" 																		# Fourth part of successful deallocate message. End of deallocation messages

	# Holds the user command string and variable name input
	UserString: 		.space 22

	# Holds user-defined variable names (64 names x 21 max size = 1344 bytes)
	# Max size of 21 = 20 characters + '\0'
	VarNames:			.space 1344

	# This shows the data table for all 64 chunks of data
	ChunkList: 			.word	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	# This shows the number of chunks allocated for each variable
	ChunkCountList: 	.word	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	# This shows the index of the first chunk allocate for each variable
	ChunkIndexList: 	.word	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0