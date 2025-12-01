require 'rails_helper'

RSpec.describe Answer, type: :model do
  it 'is valid with required attributes' do
    answer = build(:answer)
    expect(answer).to be_valid
  end

  it 'is invalid without a body' do
    answer = build(:answer, body: nil)
    expect(answer).not_to be_valid
    expect(answer.errors[:body]).to include("can't be blank")
  end

  it 'belongs to a post and user' do
    answer = create(:answer)
    expect(answer.post).to be_present
    expect(answer.user).to be_present
  end

  it 'creates a thread identity after creation' do
    answer = create(:answer)

    identity = ThreadIdentity.find_by(user: answer.user, post: answer.post)
    expect(identity).to be_present
  end

  describe '#clear_post_acceptance' do
    it 'clears acceptance and unlocks the post when the accepted answer is destroyed' do
      post = create(:post)
      answer = create(:answer, post: post)
      post.update(accepted_answer: answer, locked_at: Time.current, status: Post::STATUSES[:solved])

      expect { answer.destroy }.to change { post.reload.accepted_answer }.to(nil)

      post.reload
      expect(post.locked_at).to be_nil
      expect(post.status).to eq(Post::STATUSES[:open])
    end

    it 'leaves acceptance intact when a different answer is destroyed' do
      post = create(:post)
      accepted = create(:answer, post: post)
      other_answer = create(:answer, post: post)
      post.update(accepted_answer: accepted, locked_at: Time.current, status: Post::STATUSES[:solved])

      expect {
        other_answer.destroy
      }.not_to change { post.reload.accepted_answer_id }

      post.reload
      expect(post.accepted_answer_id).to eq(accepted.id)
      expect(post.locked_at).to be_present
      expect(post.status).to eq(Post::STATUSES[:solved])
    end
  end

  it 'is invalid when the post is locked' do
    post = create(:post, locked_at: Time.current)
    answer = build(:answer, post: post)

    expect(answer).not_to be_valid
    expect(answer.errors[:base]).to include('This thread is locked. No new answers can be added.')
  end

  describe '#post_must_be_open' do
    it 'passes validation when post is nil (safe navigation branch)' do
      answer = build(:answer)
      answer.post = nil
      answer.valid?
      # post_must_be_open passes due to safe navigation, but belongs_to fails
      expect(answer.errors[:base]).not_to include('This thread is locked. No new answers can be added.')
    end
  end

  describe '#record_revision!' do
    let(:answer) { create(:answer) }
    let(:editor) { create(:user) }

    it 'skips revision when body unchanged' do
      expect {
        answer.record_revision!(editor: editor, previous_body: answer.body)
      }.not_to change { answer.answer_revisions.count }
    end

    it 'creates revision when body changes' do
      original_body = answer.body
      answer.update!(body: 'Updated body content')

      expect {
        answer.record_revision!(editor: editor, previous_body: original_body)
      }.to change { answer.answer_revisions.count }.by(1)
    end
  end

  describe 'redaction fields' do
    it 'defaults to visible' do
      answer = create(:answer)

      expect(answer.redaction_state).to eq('visible')
    end

    it 'requires a replacement body when redacted' do
      answer = build(:answer, redaction_state: :redacted, redacted_body: nil)

      expect(answer).not_to be_valid
      expect(answer.errors[:redacted_body]).to include('must be provided when content is redacted')
    end
  end
end
