# frozen_string_literal: true

require_relative 'events_repo'
require 'luna_park/errors'
require 'json'

module CycloneLariat
  class Middleware
    def initialize(dataset:, errors_notifier: nil, message_notifier: nil, repo: EventsRepo)
      @events_repo      = repo.new(dataset)
      @message_notifier = message_notifier
      @errors_notifier  = errors_notifier
    end

    def call(_worker_instance, queue, _sqs_msg, body)
      log_received_message queue, body

      catch_standard_error(queue, body) do
        event = Event.wrap(JSON.parse(body[:'Message']))

        catch_business_error(event) do
          store_in_dataset(event) { yield }
        end
      end
    end

    private

    attr_reader :errors_notifier, :message_notifier, :events_repo

    def log_received_message(queue, body)
      message_notifier&.info 'Receive message', queue: queue, aws_message_id: body[:'MessageId'], message: body[:'Message']
    end

    def store_in_dataset(event)
      true if events_repo.exists?(uuid: event.uuid)

      events_repo.create(event)
      yield
      events_repo.processed! uuid: event.uuid
    end

    def catch_business_error(event)
      yield
    rescue LunaPark::Errors::Business => e
      errors_notifier&.warning(e, event: event)
    end

    def catch_standard_error(queue, body)
      yield
    rescue StandardError => e
      errors_notifier&.error(e, queue: queue, aws_message_id: body[:'MessageId'], message: body[:'Message'])
      raise e
    end
  end
end
