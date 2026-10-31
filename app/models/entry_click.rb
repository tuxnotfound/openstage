class EntryClick < ApplicationRecord
  # Holds no visitor hash any more (ClearClickAndBadgeIpHashes). The column is
  # dropped in the next release, once no running code writes it.
  self.ignored_columns += %w[ip_hash]

  belongs_to :user
  belongs_to :entry
end
