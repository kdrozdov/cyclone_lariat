# frozen_string_literal: true

require 'luna_park/notifiers/log'
require_relative '../../lib/cyclone_lariat/middleware'
require_relative '../../lib/cyclone_lariat/messages_repo'

RSpec.describe CycloneLariat::Middleware do
  describe '#call' do
    subject(:receive_event) do
      middleware.call(nil, 'create_message', nil, { 'MessageId': 12, 'Message': msg }) do
        business_logic.call
      end
    end

    let(:business_logic) { double(call: :result) }
    let(:msg) { '{"uuid":"fcc3644b-f42c-4068-9ef9-06ceaa62b44d","publisher":"pilot","type":"event_test","version":1,"data":{"foo":1}}' }
    let(:notifier) { instance_double(LunaPark::Notifiers::Log, error: nil, warning: nil) }

    context 'when message_notifier is defined' do
      let(:middleware) { described_class.new(message_notifier: notifier) }

      it 'should write INFO log message' do
        expect(notifier).to receive(:info).with(
          'Receive message',
          queue: 'create_message',
          message: {
            data: { foo: 1 },
            publisher: 'pilot',
            type: 'event_test',
            uuid: 'fcc3644b-f42c-4068-9ef9-06ceaa62b44d',
            version: 1
          }
        )

        receive_event
      end
    end

    context 'when errors_notifier is defined' do
      let(:middleware) { described_class.new(errors_notifier: notifier) }

      context 'no any one exception is handled' do
        it 'should not write log message' do
          expect(notifier).to_not receive(:post)
          receive_event
        end
      end

      context 'receive business error' do
        subject(:receive_event) do
          middleware.call(nil, 'create_message', nil, { 'MessageId': 12, 'Message': msg }) do
            raise LunaPark::Errors::Business
          end
        end

        it 'should write ERROR notify' do
          expect(notifier).to receive(:error)
          receive_event
        end

        it 'should not raise error' do
          expect { receive_event }.to_not raise_error
        end
      end

      context 'receive system error' do
        subject(:receive_event) do
          middleware.call(nil, 'create_message', nil, { 'MessageId': 12, 'Message': msg }) do
            raise LunaPark::Errors::System
          end
        end

        it 'should write ERROR notify and raise this error' do
          expect(notifier).to receive(:error)
          expect { receive_event }.to raise_error(LunaPark::Errors::System)
        end
      end

      context 'receive system exception' do
        subject(:receive_event) do
          middleware.call(nil, 'create_message', nil, { 'MessageId': 12, 'Message': msg }) do
            raise StandardError
          end
        end

        it 'should write ERROR notify and raise this error' do
          expect(notifier).to receive(:error)
          expect { receive_event }.to raise_error(StandardError)
        end
      end
    end

    context 'when messages_repo is defined' do
      let(:dataset) { double }
      let(:messages_repo) { instance_double CycloneLariat::MessagesRepo }
      let(:messages_repo_class) { class_double(CycloneLariat::MessagesRepo, new: messages_repo) }
      let(:middleware) { described_class.new(dataset: dataset, repo: messages_repo_class) }
      let(:event) { instance_double CycloneLariat::Event, processed?: true }

      context 'when event is already exists in dataset' do
        let(:messages_repo) { instance_double CycloneLariat::MessagesRepo, find: event }
        it { is_expected.to be true }
        it 'should not run business logic' do
          expect(business_logic).to_not receive(:call)
          receive_event
        end

        it 'should not event as processed' do
          expect(messages_repo).to_not receive(:processed!)
          receive_event
        end

        it 'should not crete new event in repository' do
          expect(messages_repo).to_not receive(:create)
          receive_event
        end
      end

      context 'when event does not exists in dataset' do
        let(:messages_repo) { instance_double CycloneLariat::MessagesRepo, find: nil, create: nil, processed!: true }

        it { is_expected.to be true }

        it 'should run business logic' do
          expect(business_logic).to receive(:call)
          receive_event
        end

        it 'should mark event as processed' do
          expect(messages_repo).to receive(:processed!)
          receive_event
        end

        it 'should not crete new event in repository' do
          expect(messages_repo).to receive(:create)
          receive_event
        end
      end
    end

    context 'when dataset is not defined' do
      let(:middleware) { described_class.new(dataset: nil, repo: nil) }

      it { is_expected.to be :result }

      it 'should run business logic' do
        expect(business_logic).to receive(:call)
        receive_event
      end
    end
  end
end
