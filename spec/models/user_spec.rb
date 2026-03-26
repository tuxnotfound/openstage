require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:github_uid) }
    it { is_expected.to validate_uniqueness_of(:github_uid) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
    it { is_expected.to validate_length_of(:username).is_at_least(2).is_at_most(39) }

    it "allows valid usernames" do
      expect(build(:user, username: "pedro")).to be_valid
      expect(build(:user, username: "pedro-cioga")).to be_valid
      expect(build(:user, username: "pedro_123")).to be_valid
    end

    it "rejects usernames with invalid characters" do
      expect(build(:user, username: "pedro cioga")).not_to be_valid
      expect(build(:user, username: "pedro@cioga")).not_to be_valid
    end
  end

  describe "#can_change_username?" do
    it "returns true when username has never been changed" do
      user = build(:user, username_changed_at: nil)
      expect(user.can_change_username?).to be true
    end

    it "returns true when 30+ days have passed" do
      user = build(:user, username_changed_at: 31.days.ago)
      expect(user.can_change_username?).to be true
    end

    it "returns false when changed less than 30 days ago" do
      user = build(:user, username_changed_at: 10.days.ago)
      expect(user.can_change_username?).to be false
    end
  end

  describe ".from_github_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        uid: "12345",
        info: { nickname: "tuxnotfound", name: "Pedro Cioga", image: "https://avatars.example.com/u/12345" },
        credentials: { token: "gho_test_token" }
      )
    end

    it "creates a new user from GitHub auth" do
      user = described_class.from_github_omniauth(auth)
      expect(user.github_uid).to eq("12345")
      expect(user.github_username).to eq("tuxnotfound")
      expect(user.username).to eq("tuxnotfound")
      expect(user.display_name).to eq("Pedro Cioga")
      expect(user.github_access_token).to eq("gho_test_token")
    end

    it "finds an existing user and updates their token" do
      existing = create(:user, github_uid: "12345", github_access_token: "old_token")
      user = described_class.from_github_omniauth(auth)
      expect(user.id).to eq(existing.id)
      expect(user.github_access_token).to eq("gho_test_token")
    end

    it "does not overwrite existing username for returning users" do
      create(:user, github_uid: "12345", username: "custom_name")
      user = described_class.from_github_omniauth(auth)
      expect(user.username).to eq("custom_name")
    end
  end
end
