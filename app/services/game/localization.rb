# frozen_string_literal: true

module Game
  # Provides localized display names for game systems and factions
  class Localization
    class << self
      def config
        @config ||= load_config
      end

      def reload!
        @config = load_config
      end

      def localized(hash_or_string, locale = I18n.locale)
        case hash_or_string
        when String
          hash_or_string
        when Hash
          preferred = hash_or_string[locale.to_s].presence
          fallback_en = hash_or_string['en'].presence
          fallback_fr = hash_or_string['fr'].presence
          preferred || fallback_en || fallback_fr || hash_or_string.values.compact.first
        end
      end

      def find_system_translations(system_name)
        return nil if system_name.blank?

        config.fetch('game_systems', []).each do |sys|
          name = sys['name']
          names = name.is_a?(Hash) ? name : { 'en' => name, 'fr' => name }
          return names if names.value?(system_name)
        end

        nil
      end

      def find_faction_translations(system_name, faction_name)
        return nil if system_name.blank? || faction_name.blank?

        system_entry = config.fetch('game_systems', []).find do |sys|
          names = sys['name'].is_a?(Hash) ? sys['name'] : { 'en' => sys['name'], 'fr' => sys['name'] }
          names.value?(system_name)
        end

        return nil unless system_entry

        (system_entry['factions'] || []).each do |f|
          names = f.is_a?(Hash) ? f : { 'en' => f, 'fr' => f }
          return names if names.value?(faction_name)
        end

        nil
      end

      private

      def load_config
        path = Rails.root.join('config/game_systems.yml')
        return {} unless File.exist?(path)

        YAML.load_file(path) || {}
      rescue Psych::SyntaxError
        {}
      end
    end
  end
end
