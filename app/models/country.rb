# A country as analytics' lists name it: the English short name of the ISO
# 3166-1 alpha-2 code Cloudflare and Openstage's script send
# (config/countries.yml), or the code as it is when it names none.
module Country
  NAMES = YAML.load_file(Rails.root.join("config/countries.yml")).freeze

  def self.name_of(code)
    NAMES.fetch(code.to_s.upcase, code)
  end
end
