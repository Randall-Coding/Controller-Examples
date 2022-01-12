class Interview < ApplicationRecord
  belongs_to :user
  belongs_to :ally
  belongs_to :interview_template

  has_many :interview_comments, dependent: :destroy
  has_many :interview_questions, through: :interview_template, source: :interview_questions
  has_many :comments, class_name: 'InterviewComment'  #alias.  don't delete.
  has_many :answered_questions, class_name: 'InterviewAnsweredQuestion', dependent: :destroy
  has_many :interview_events, dependent: :destroy

  default_scope {includes(:ally,:interview_template)}

  validate :check_for_duplicate, on: :create

  before_create :set_defaults
  before_update  :send_confirmation_email

  validates :start_time, presence: true
  validates :start_date, presence: true

  def set_defaults
    set_token
    set_cohort_and_phase
    self.stars ||= 0
  end

  def send_confirmation_email
    if start_time_changed? || start_date_changed?
      InterviewMailer.confirmation_changed(self).deliver!
    end
  end

  def check_for_duplicate
    if Interview.where(cohort:user.cohort,ally_id:ally_id,started:nil).present?
      errors[:base] << "Duplicate interview for this cohort"
    else
      return true
    end
  end

  def room_created?
    self.room_sid?
  end

  def questions
    interview_template.questions
  end

  def template
    interview_template
  end

  # Live question data
  def duration_in_minutes
    # assuming seconds
    duration / 60 if duration
  end

  def flag_emotions
    interview_events.where(data_type:'emotion')
  end

  def flag_emotions_raw
    self[:flag_emotions]
  end

  def aborts
    interview_events.where(data_type:'abort')
  end

  def aborts_raw
    self[:aborts]
  end

  def ask_mores
    interview_events.where(data_type:'ask_more')
  end

  def ask_mores_raw
    self[:ask_mores]
  end

  # Live question data
  def start_time(offset = nil)
    if offset
      self[:start_time] ? (self[:start_time] + offset).strftime("%H:%M%P") : nil
    else
      self[:start_time] ? self[:start_time].strftime("%H:%M%P") : nil
    end
  end

  def start_time_raw
    self[:start_time]
  end

  def start_date_and_time
    Time.zone.parse(start_date.to_s + ' ' + start_time).strftime('%B %d, %Y %H:%M%P %Z')
  end

  def start_date_pretty
    start_date.strftime('%A, %B %d, %Y')
  end

  def set_token
    self.token = token || SecureRandom.urlsafe_base64(30)
  end

  def set_cohort_and_phase
    self.cohort ||= user.cohort
    self.phase ||= user.phase
  end

  def all_events
    list = comments.map do |comment|
      comment.attributes
    end
    events = interview_events.map do |event|
      event.attributes
    end

    list = list + events
    list.sort_by{|h| h["timestamp"]}
  end

  def events
    interview_events
  end

  def events_by_question_json
    questions.each_with_index.map do |question, index|
      InterviewEvent.select{|event| event.interview_question_id == question.id}.map do |event|
        event.attributes
      end
    end
  end

  def percentages_of_events
    total_events = interview_events.count
    interview_questions.map do |question|
      if total_events > 0
        (interview_events.where(interview_question_id: question.id).count / total_events.to_f * 100)
      else
        0
      end
    end
  end

  def generate_video_url
    composition_sid = self.composition
    uri = "https://video.twilio.com/v1/Compositions/#{composition_sid}/Media?Ttl=3600"
    response = TWILIO_CLIENT.request("video.twilio.com", 433, 'GET', uri)
    stream_url = response.body["redirect_to"]
  end

  def delete_room_recordings(room_sid)
    recordings = TWILIO_CLIENT.video
                    .rooms(room_sid)
                    .recordings
                    .list
    recordings.each do |r|
      r.delete
    end
  end
end
