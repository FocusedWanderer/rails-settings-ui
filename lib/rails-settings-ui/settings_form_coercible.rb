require 'dry-types'

module RailsSettingsUi
  module Types
    include Dry::Types.module

    module CustomCoercions

      class Symbol
        def self.[](value)
          value.to_sym
        end
      end

      class Hash
        def self.[](value)
          JSON.parse(value.gsub(/\=\>/, ':'))
        end
      end

      class Array
        def self.[](value)
          # array presented in checkboxes
          case value.class.name
          when 'Hash', 'ActiveSupport::HashWithIndifferentAccess'
            value.keys.map!(&:to_sym)
          when 'ActionController::Parameters'
            value.select{ |_,v| v == 'on' }.keys.map!(&:to_sym)
          else
            # or in select tag
            value.to_sym
          end
        end
      end

    end
  end

  class NotCoercibleError < StandardError;end

  class SettingsFormCoercible
    attr_reader :settings, :default_settings

    def initialize(default_settings, settings)
      @default_settings = default_settings
      @settings = settings
    end

    def coerce!
      settings.to_h.symbolize_keys!.each do |name, value|
        default_value_class = default_settings[name].class
        coercible_type = coercions_map[default_value_class]
        raise NotCoercibleError, "can't coerce #{default_value_class}" unless coercible_type
        settings[name] = coercible_type[value]
      end
      set_default_boolean_value!(settings)
      settings
    end

    def coercions_map
      {
        String => Types::Coercible::String,
        Symbol => Types::CustomCoercions::Symbol,
        Fixnum => Types::Form::Int,
        ActiveSupport::HashWithIndifferentAccess => Types::CustomCoercions::Hash,
        ActiveSupport::Duration => Types::Form::Int,
        Float => Types::Form::Float,
        Array => Types::CustomCoercions::Array,
        FalseClass => Types::Form::Bool,
        TrueClass => Types::Form::Bool
      }
    end

    private

    def set_default_boolean_value!(settings)
      default_settings.each do |name, value|
        setting_value = settings[name.to_sym]
        next if setting_value.present?

        settings[name.to_sym] = case value.class.name
                                when 'TrueClass', 'FalseClass'
                                  false
                                when 'Array'
                                  []
                                end
      end
    end

  end
end
