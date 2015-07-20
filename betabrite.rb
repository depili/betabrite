#!/usr/bin/env ruby

require 'serialport'

class Betabrite
	NULL = 0.chr
	SOH  = 1.chr
	STX  = 2.chr
	ETX  = 3.chr
	EOT  = 4.chr
	ESC  = 27.chr
	
	PRIORITY_FILE = 0x30.chr # Overrides other messages on the sign if it exists
	
	def initialize(tty)
		# Open the serial port, 9600 baud, 7 data bits, 1 stop bit, even parity
		@sp = SerialPort.new(tty, 9600, 7, 1, SerialPort::EVEN)
		set_time
		set_weekday
		set_time_format
	end
	
	def write_text(file, mode, text)
		data = command(:write_text)
		data << file
		data << ESC
		data << 32.chr # Use middle line (we have only one line)
		data << mode
		data << text
		send_command data
	end
	
	def write_string(file, text)
		data = command(:write_string)
		data << file
		data << text
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
	
	
	# Text colors
	def text_color(color)
		
	end
	
	def send_command(data)
		message = header + data + ETX + checksum(data) + EOT
		@sp.puts message
	end
	
end