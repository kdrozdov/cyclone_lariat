# frozen_string_literal: true

require_relative 'cyclone_lariat/options'
require_relative 'cyclone_lariat/generators/topic'
require_relative 'cyclone_lariat/generators/queue'
require_relative 'cyclone_lariat/clients/sns'
require_relative 'cyclone_lariat/errors'
require_relative 'cyclone_lariat/messages/event'
require_relative 'cyclone_lariat/messages_mapper'
require_relative 'cyclone_lariat/messages_repo'
require_relative 'cyclone_lariat/migration'
require_relative 'cyclone_lariat/middleware'
require_relative 'cyclone_lariat/version'

module CycloneLariat
  extend Generators::Topic
  extend Generators::Queue
  class << self
    def config
      @config ||= Options.new
    end

    def configure
      yield(config)
    end
  end
end
