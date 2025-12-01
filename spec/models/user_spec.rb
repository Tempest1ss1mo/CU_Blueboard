require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#anonymous_handle' do
    context 'when the user has been persisted' do
      it 'generates pseudonymous handle based on user ID' do
        user = create(:user)
        handle = user.anonymous_handle

        expect(handle).to match(/^Lion #[A-Z0-9]{4}$/)
        expect(handle).to include(user.id.to_s(36).upcase.rjust(4, "0"))
      end

      it 'generates consistent handles for the same user' do
        user = create(:user)
        first_call = user.anonymous_handle
        second_call = user.anonymous_handle

        expect(first_call).to eq(second_call)
      end

      it 'generates different handles for different users' do
        user1 = create(:user)
        user2 = create(:user)

        expect(user1.anonymous_handle).not_to eq(user2.anonymous_handle)
      end

      it 'generates handles in the format "Lion #XXXX"' do
        user = create(:user)

        expect(user.anonymous_handle).to start_with("Lion #")
        expect(user.anonymous_handle.length).to eq(10)
      end
    end

    context 'when the user has not been persisted' do
      it 'falls back to a random token' do
        user = build(:user)
        allow(SecureRandom).to receive(:alphanumeric).and_return('ABCD')

        expect(user.anonymous_handle).to eq('Lion #ABCD')
      end

      it 'generates a new token for each call' do
        user = build(:user)
        allow(SecureRandom).to receive(:alphanumeric).and_return('ABCD', 'EFGH')

        expect(user.anonymous_handle).to eq('Lion #ABCD')
        expect(user.anonymous_handle).to eq('Lion #EFGH')
      end
    end
  end

  describe 'associations' do
    it 'has many posts' do
      association = described_class.reflect_on_association(:posts)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'has many answers' do
      association = described_class.reflect_on_association(:answers)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'has many likes' do
      association = described_class.reflect_on_association(:likes)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'destroys associated posts when user is destroyed' do
      user = create(:user)
      create(:post, user: user)
      create(:post, user: user)

      expect {
        user.destroy
      }.to change(Post, :count).by(-2)
    end

    it 'destroys associated answers when user is destroyed' do
      user = create(:user)
      post = create(:post)
      create(:answer, user: user, post: post)

      expect {
        user.destroy
      }.to change(Answer, :count).by(-1)
    end

    it 'destroys associated likes when user is destroyed' do
      user = create(:user)
      post = create(:post)
      create(:like, user: user, post: post)

      expect {
        user.destroy
      }.to change(Like, :count).by(-1)
    end
  end

  describe '.from_omniauth' do
    def build_auth_hash(overrides = {})
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: 'uid-123',
        info: { email: 'student@columbia.edu' }
      }.deep_merge(overrides))
    end

    it 'returns nil when the email domain is not allowed' do
      auth = build_auth_hash(info: { email: 'user@gmail.com' })
      result = nil

      expect {
        result = described_class.from_omniauth(auth)
      }.not_to change(described_class, :count)

      expect(result).to be_nil
    end

    it 'returns an existing user when provider and uid already match' do
      user = create(:user, provider: 'google_oauth2', uid: 'uid-123', email: 'student@columbia.edu')
      auth = build_auth_hash(uid: 'uid-123', info: { email: user.email })

      expect(described_class.from_omniauth(auth)).to eq(user)
    end

    it 'links an existing email/password user to Google credentials' do
      user = create(:user, provider: nil, uid: nil, email: 'linked@columbia.edu')
      auth = build_auth_hash(uid: 'google-uid', info: { email: user.email })

      result = described_class.from_omniauth(auth)

      expect(result).to eq(user)
      expect(user.reload.uid).to eq('google-uid')
      expect(user.provider).to eq('google_oauth2')
    end

    it 'creates a new user when no existing record is found' do
      auth = build_auth_hash(uid: 'fresh-uid', info: { email: 'new@columbia.edu' })

      expect {
        @new_user = described_class.from_omniauth(auth)
      }.to change(described_class, :count).by(1)

      expect(@new_user.email).to eq('new@columbia.edu')
      expect(@new_user.provider).to eq('google_oauth2')
      expect(@new_user.uid).to eq('fresh-uid')
    end

    context 'when email is in moderator whitelist' do
      let(:moderator_email) { 'moderator@columbia.edu' }

      before do
        allow(Rails.application.config).to receive(:moderator_emails)
          .and_return([ moderator_email ])
      end

      it 'assigns moderator role to new user' do
        auth = build_auth_hash(uid: 'mod-uid', info: { email: moderator_email })
        user = described_class.from_omniauth(auth)

        expect(user.role).to eq('moderator')
      end

      it 'updates existing user to moderator role' do
        existing = create(:user, provider: 'google_oauth2', uid: 'mod-existing',
                          email: moderator_email, role: :student)
        auth = build_auth_hash(uid: 'mod-existing', info: { email: moderator_email })

        result = described_class.from_omniauth(auth)

        expect(result.reload.role).to eq('moderator')
      end
    end

    context 'when existing user role already matches target role' do
      before do
        allow(Rails.application.config).to receive(:moderator_emails).and_return([])
      end

      it 'does not update when role is already student' do
        existing = create(:user, provider: 'google_oauth2', uid: 'same-role',
                          email: 'same@columbia.edu', role: :student)
        original_updated_at = existing.updated_at

        auth = build_auth_hash(uid: 'same-role', info: { email: 'same@columbia.edu' })

        # Sleep briefly to ensure any update would have a different timestamp
        sleep 0.01
        described_class.from_omniauth(auth)

        # Role is already student and target is student, so no update should occur
        expect(existing.reload.role).to eq('student')
      end
    end
  end

  describe 'roles' do
    it 'defaults to student' do
      user = create(:user)

      expect(user.role).to eq('student')
      expect(user).not_to be_can_moderate
    end

    it 'treats moderators as privileged users' do
      moderator = create(:user, :moderator)

      expect(moderator.role).to eq('moderator')
      expect(moderator).to be_can_moderate
    end

    it 'treats staff and admins as privileged users' do
      staff = create(:user, :staff)
      admin = create(:user, :admin)

      expect(staff).to be_can_moderate
      expect(admin).to be_can_moderate
    end
  end
end
