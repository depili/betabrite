#!/usr/bin/env ruby

require 'serialport'

class Betabrite
	NULL = 0.chr
	SOH  = 1.chr
	STX  = 2.chr
	ETX  = 3.chr
	EOT  = 4.chr
	ESC  = 27.chr
	
	NEW_PAGE = 0x0c.chr
	NEW_LINE = 0x0d.chr
	
	CALL_STRING = 0x10.chr # Must be followed by string file label
	CALL_TIME = 0x13.chr
	CALL_DOTS = 0x14.chr # Must be followed by small dots file label
	
	SPEED_1 = 0x15.chr
	SPEED_2 = 0x16.chr
	SPEED_3 = 0x17.chr
	SPEED_4 = 0x18.chr
	SPEED_5 = 0x19.chr
	NO_HOLD = 0x09.chr
	
	SET_COLOR = 0x1c.chr # Must be followed by 1-9, A, B, C
	COLOR_RED				= SET_COLOR + '1'
	COLOR_GREEN			= SET_COLOR + '2'
	COLOR_AMBER			= SET_COLOR + '3'
	COLOR_DIM_RED		= SET_COLOR + '4'
	COLOR_DIM_GREEN = SET_COLOR + '5'
	COLOR_BROWN 		= SET_COLOR + '6'
	COLOR_ORANGE 		= SET_COLOR + '7'
	COLOR_YELLOW 		= SET_COLOR + '8'
	COLOR_RAINBOW1 	= SET_COLOR + '9'
	COLOR_RAINBOW2 	= SET_COLOR + 'A'
	COLOR_MIX 			= SET_COLOR + 'B'
	COLOR_AUTO 			= SET_COLOR + 'C'
	
	SET_FONT = 0x1a.chr
	FONT_FIVE_STD 	= SET_FONT + '1'
	FONT_FIVE_BOLD 	= SET_FONT + '2'
	FONT_FIVE_WIDE	= SET_FONT + 0x3b.chr
	FONT_SEVEN_STD 	= SET_FONT + '3'
	FONT_SEVEN_BOLD	= SET_FONT + '4'
	FONT_SEVEN_WIDE = SET_FONT + 0x3c.chr
	
	FONT_SPACING_PRORTIONAL	= 0x1e.chr + '0'
	FONT_SPACING_FIXED			= 0x1e.chr + '1'
	
	PRIORITY_FILE = 0x30.chr # Overrides other messages on the sign if it exists
	
	def initialize(tty)
		# Open the serial port, 9600 baud, 7 data bits, 1 stop bit, even parity
		@sp = SerialPort.new(tty, 9600, 7, 1, SerialPort::EVEN)
		set_time
		set_weekday
		set_time_format
	end
	
	def write_text(file, mode, text)
		# Encode the display mode
		case mode
		when :rotate # Text scrolls from right to left
			mode = 'a'
		when :hold # Text is displayed centered, no animation
			mode = 'b'
		when :flash
			mode = 'c' # At least my betabrite reboots with this mode
		when :roll_up
			mode = 'e'
		when :roll_down
			mode = 'f'
		when :roll_left
			mode = 'g'
		when :roll_right
			mode = 'h'
		when :wipe_up
			mode = 'i'
		when :wipe_down
			mode = 'j'
		when :wipe_left
			mode = 'k'
		when :wipe_right
			mode = 'l'
		when :scroll
			mode = 'm'
		when :automode
			mode = 'o'
		when :roll_in
			mode = 'p'
		when :roll_out
			mode = 'q'
		when :wipe_in
			mode = 'r'
		when :wipe_out
			mode = 's'
		when :c_rotate
			mode = 't'
		when :twinkle # Pixels of the text twinkle on the display
			mode = 'n0'
		when :sparkle # Draw the new text one pixel at a time
			mode = 'n1'
		when :snow # Pixels snow down from top
			mode = 'n2'
		when :interlock
			mode = 'n3'
		when :switch
			mode = 'n4'
		when :slide
			mode = 'n5'
		when :spray
			mode = 'n6'
		when :starburst
			mode = 'n7'
		when :welcome
			mode = 'n8'
		when :slot_machine
			mode = 'n9' # This also crashes my betabrite
		else
			mode = 'a'
		end
		
		data = command(:write_text)
		data << file
		data << ESC
		data << 32.chr # Use middle line (we have only one line)
		data << mode
		data << escape_text(text)
		send_command data
	end
	
	def write_string(file, text)
		data = command(:write_string)
		data << file
		data << escape_text(text)
		send_command data
	end
	
	# Set the time on the sign
	def set_time(time = Time.now)
		data = command(:write_special)
		data << 0x20.chr # Set time of day command
		data << time.strftime('%H%M')
		send_command data
	end
	
	def set_weekday(day = Time.now.wday)
		data = command(:write_special)
		data << 0x26.chr # Set day of week
		data << day
		send_command data
	end
	
	def set_date(date = Time.now)
		data = command(:write_special)
		data << 0x3b.chr
		data << date.strftime('%m%d%y')
		send_command data
	end
	
	def set_time_format(ampm = false)
		data = command(:write_special)
		data << 0x27.chr # Set time format
		data << (ampm ? 'S' : 'M')
		send_command data
	end
	
	# Turn sound on or off
	def sound(sound_on = false)
		data = command(:write_special)
		data << 0x21
		data << sound_on ? 'FF' : '00'
		send_command data
	end
	
	def soft_reset
		data = command(:write_special)
		data << 0x2c.chr # Soft reset
		send_command data
	end
	
	def set_memory_map
		data = command(:write_special)
		data << 0x24.chr
		
		# Create 5 text files A-E, max 256 byte size, run time set as always
		('A'..'E').each do |i|
			data << "#{i}AL0100FF00"
		end
		
		# Create 10 string files with labels 1-10 and max 125 byte size
		(1..10).each do |i|
			data << "#{i}BL007D0000"
		end
		
		send_command data
	end
	
	def read_error_register
		data = command(:read_special)
		data << 0x2a.chr
		send_command data
	end
	
	def read_memory_size
		data = command(:read_special)
		data << 0x23.chr
		send_command data
	end
	
	private
	
	# Header is 5-10 nulls (0x00) followed by start of header (0x01)
	# Then comes the sign type code and address, we are only communicating
	# with one sign, so send "Z00" for "broadcast to all signs"
	# Then we send start-of-text (0x02). After that its time for the command
	def header
		h = String.new
		# five nulls for the sign to detenct the baud rate
		5.times do
			h << NULL
		end
		# Start of header (SOH)
		h << SOH
		# Broadcast to all signs
		h << 'Z00'
		# Start of text (STX)
		h << STX
		return h
	end
	
	# Subset of command codes. They are the next thing to send after STX
	def command(cmd)
		case cmd
		when :write_text
			'A'
		when :write_special
			'E'
		when :read_special
			'F'
		when :write_string
			'G'
		when :write_smalldots
			'I'
		when :write_rgb
			'K'
		when :write_largedots
			'M'
		end	
	end
	
	# Calculates the checksum for the message
	# This is a running 16bit sum starting at the STX
	# and ending at the ETX, both control codes are included.
	def checksum(data)
		sum = 0
		data.each_char do |c|
			sum += c.ord
		end
		sum += STX.ord + ETX.ord
		sum = sum % 65535
		return (sprintf "%04x", sum).upcase
	end
	
	# Convert some non-ascii characters into escaped extended characters for the panel
	def escape_text(text)
		esc = 0x08.chr
		extended_chars = {
			'ä' => (esc + 0x24.chr),
			'Ä' => (esc + 0x2e.chr),
			'ö' => (esc + 0x34.chr),
			'Ö' => (esc + 0x39.chr),
			'å' => (esc + 0x26.chr),
			'Å' => (esc + 0x2f.chr)
		}
		
		extended_chars.each_pair do |k,v|
			text.gsub! k, v
		end
		
		escaped = String.new
		
		text.each_char do |c|
			if c.ord > 127
				escaped << '_'
			else
				escaped << c
			end
		end
		return escaped
	end
	
	def send_command(data)
		message = header + data + ETX + checksum(data) + EOT
		@sp.puts message
	end
	
end