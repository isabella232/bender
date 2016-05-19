MESSAGE_DELAY = 0.5
GC_DELAY = 5
SELECT_DELAY = 0.5

@pin = ARGV[0]
@timeout = ARGV[1].to_i

base_path = "/sys/class/gpio/gpio#{@pin}"
File.open("/sys/class/gpio/export", "w") {|f| f.write(@pin.to_s) } unless File.exist?(base_path)
File.open("#{base_path}/direction", "w") {|f| f.write("in") }
File.open("#{base_path}/edge", "w") {|f| f.write("both") }

@pin_file = File.open("#{base_path}/value", "r")
@running = true

Signal.trap(:INT)  { @running = false }
Signal.trap(:TERM) { @running = false }
Signal.trap(:QUIT) { @running = false }

$stdout.sync = true

@read_group = [@pin_file]

def read
  @pin_file.rewind
  @pin_file.read.to_i
end

def wait_for_tick
  @prev_value = read
  begin
    ready = IO.select(nil, nil, @read_group, SELECT_DELAY)
    if ready
      val = read
      ready = nil if @prev_value == val || val == 0
      @prev_value = val
    end
  end while !ready && @running && (!block_given? || yield)
  ready
end

def send_message
  $stdout.puts "#{@pin},#{@first_tick},#{@last_tick},#{@ticks}"
  $stdout.flush
  @last_message = Time.now
end

GC.start
$stdout.puts "ready"
$stdout.flush
# Loop while we are running or a pour is in progress
while @running
  # Wait for a pour to start
  ticked = wait_for_tick

  break if !@running

  # Prevent GC from running during the pour
  # GC.disable
  # Rescue block so we always re-enable GC
  begin
    @now = Time.now
    @first_tick = @last_tick = @now.to_f
    @ticks = 1

    send_message

    while (@now.to_f - @last_tick) < @timeout
      ticked = wait_for_tick do
        now = Time.now
        (now.to_f - @last_tick) < @timeout && (now - @last_message) < MESSAGE_DELAY
      end

      @now = Time.now

      if ticked
        @last_tick = @now.to_f
        @ticks += 1
      end

      send_message if @now - @last_message > MESSAGE_DELAY
    end
  ensure
    # GC.enable
    GC.start
  end
end

$stdout.puts "Done"