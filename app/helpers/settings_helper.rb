module SettingsHelper
  # Rails' zones, and the builder's own, which a browser can name otherwise.
  def zone_options(current)
    [ current, *ActiveSupport::TimeZone.all.map { |zone| zone.tzinfo.identifier } ].compact.uniq.sort
                                                                                   .map { |zone| [ zone.tr("_", " "), zone ] }
  end
end
