# Sensor ticks is stored for calibration purposes only

# Volume is stored in fluid ounces
# however most sensors report as pulses per L
# Swissflow: between 5400 to 6100 pulses/L
# ml * 0.033814 = fl oz

class Pour < ActiveRecord::Base
  belongs_to :keg
  belongs_to :user

  before_save :calculate_duration

  scope :finished, lambda { where('finished_at IS NOT NULL') }
  scope :non_guest, lambda { where('user_id > 0') }
  scope :for_listing, lambda { where('volume IS NOT NULL').includes(:keg, :user).order('created_at desc') }

  def complete?
    finished_at.nil? ? false : (Time.now - finished_at) > Setting.pour_timeout
  end

  private

  def calculate_duration
    self.duration = finished_at - started_at if finished_at && started_at
  end
end
