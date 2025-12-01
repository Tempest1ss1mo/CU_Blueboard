require 'rails_helper'

RSpec.describe RedactionService, type: :service do
  let(:student) { create(:user) }
  let(:moderator) { create(:user, :moderator) }
  let(:staff) { create(:user, :staff) }
  let(:post) { create(:post, user: student, body: 'Original post content') }
  let(:answer) { create(:answer, user: student, body: 'Original answer content') }

  describe '.redact_post' do
    context 'when moderator has privileges' do
      it 'redacts the post successfully' do
        result = RedactionService.redact_post(
          post: post,
          moderator: moderator,
          reason: 'harassment',
          state: :redacted
        )

        expect(result).to be true
        post.reload
        expect(post.redaction_state).to eq('redacted')
        expect(post.redacted_by).to eq(moderator)
        expect(post.redacted_reason).to eq('harassment')
        expect(post.redacted_body).to eq('Original post content')
        expect(post.body).to eq('[Content removed by CU moderators for policy violations]')
      end

      it 'creates an audit log entry' do
        expect {
          RedactionService.redact_post(
            post: post,
            moderator: moderator,
            reason: 'harassment'
          )
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq('post_redacted')
        expect(log.user).to eq(student)
        expect(log.metadata['moderator_id']).to eq(moderator.id)
        expect(log.metadata['reason']).to eq('harassment')
      end

      it 'supports partial redaction' do
        result = RedactionService.redact_post(
          post: post,
          moderator: moderator,
          reason: 'pii',
          state: :partial
        )

        expect(result).to be true
        post.reload
        expect(post.redaction_state).to eq('partial')
        expect(post.body).to eq('[Portions of this content have been redacted by CU moderators]')
      end

      it 'preserves stored content when already redacted' do
        post.update!(
          redaction_state: :partial,
          redacted_body: 'Original body',
          body: '[Portions of this content have been redacted by CU moderators]'
        )

        result = RedactionService.redact_post(
          post: post,
          moderator: moderator,
          reason: 'spam',
          state: :redacted
        )

        expect(result).to be true
        post.reload
        expect(post.redacted_body).to eq('Original body')
      end

      it 'works with staff role' do
        result = RedactionService.redact_post(
          post: post,
          moderator: staff,
          reason: 'spam'
        )

        expect(result).to be true
        post.reload
        expect(post.redacted_by).to eq(staff)
      end

      it 'returns false when the update fails' do
        allow(post).to receive(:visible?).and_return(true)
        allow(post).to receive(:update!).and_raise(StandardError, 'db error')

        expect(
          RedactionService.redact_post(
            post: post,
            moderator: moderator,
            reason: 'fails'
          )
        ).to be(false)
      end
    end

    context 'when user lacks moderation privileges' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.redact_post(
            post: post,
            moderator: student,
            reason: 'test'
          )
        }.to raise_error(ArgumentError, 'Moderator must have moderation privileges')
      end
    end

    context 'with invalid state' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.redact_post(
            post: post,
            moderator: moderator,
            reason: 'test',
            state: :invalid
          )
        }.to raise_error(ArgumentError, 'Invalid redaction state')
      end
    end
  end

  describe '.unredact_post' do
    before do
      RedactionService.redact_post(
        post: post,
        moderator: moderator,
        reason: 'test'
      )
    end

    it 'restores the post successfully' do
      result = RedactionService.unredact_post(
        post: post,
        moderator: moderator
      )

      expect(result).to be true
      post.reload
      expect(post.redaction_state).to eq('visible')
      expect(post.body).to eq('Original post content')
      expect(post.redacted_by).to be_nil
      expect(post.redacted_reason).to be_nil
      expect(post.redacted_body).to be_nil
    end

    it 'creates an audit log entry' do
      expect {
        RedactionService.unredact_post(
          post: post,
          moderator: staff
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq('post_unredacted')
      expect(log.metadata['moderator_id']).to eq(staff.id)
    end

    context 'when post is not redacted' do
      let(:visible_post) { create(:post, user: student) }

      it 'raises ArgumentError' do
        expect {
          RedactionService.unredact_post(
            post: visible_post,
            moderator: moderator
          )
        }.to raise_error(ArgumentError, 'Post is not redacted')
      end
    end

    context 'when user lacks privileges' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.unredact_post(
            post: post,
            moderator: student
          )
        }.to raise_error(ArgumentError, 'Moderator must have moderation privileges')
      end
    end

    it 'returns false when the restore update fails' do
      allow(post).to receive(:visible?).and_return(false)
      allow(post).to receive(:redacted_body).and_return('stored')
      allow(post).to receive(:body).and_return('stored')
      allow(post).to receive(:update!).and_raise(StandardError, 'db error')

      expect(
        RedactionService.unredact_post(
          post: post,
          moderator: moderator
        )
      ).to be(false)
    end
  end

  describe '.redact_answer' do
    it 'redacts the answer successfully' do
      result = RedactionService.redact_answer(
        answer: answer,
        moderator: moderator,
        reason: 'harmful_advice'
      )

      expect(result).to be true
      answer.reload
      expect(answer.redaction_state).to eq('redacted')
      expect(answer.redacted_by).to eq(moderator)
      expect(answer.redacted_reason).to eq('harmful_advice')
      expect(answer.redacted_body).to eq('Original answer content')
    end

    it 'creates an audit log entry' do
      expect {
        RedactionService.redact_answer(
          answer: answer,
          moderator: moderator,
          reason: 'test'
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq('answer_redacted')
      expect(log.metadata['answer_id']).to eq(answer.id)
    end

    it 'keeps redacted body when already hidden' do
      answer.update!(
        redaction_state: :partial,
        redacted_body: 'Stored answer',
        body: '[Portions of this content have been redacted by CU moderators]'
      )

      result = RedactionService.redact_answer(
        answer: answer,
        moderator: moderator,
        reason: 'policy',
        state: :redacted
      )

      expect(result).to be true
      answer.reload
      expect(answer.redacted_body).to eq('Stored answer')
    end

    it 'returns false when the answer update fails' do
      allow(answer).to receive(:visible?).and_return(true)
      allow(answer).to receive(:update!).and_raise(StandardError, 'db error')

      expect(
        RedactionService.redact_answer(
          answer: answer,
          moderator: moderator,
          reason: 'fails'
        )
      ).to be(false)
    end

    context 'when user lacks moderation privileges' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.redact_answer(
            answer: answer,
            moderator: student,
            reason: 'test'
          )
        }.to raise_error(ArgumentError, 'Moderator must have moderation privileges')
      end
    end

    context 'with invalid state' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.redact_answer(
            answer: answer,
            moderator: moderator,
            reason: 'test',
            state: :invalid
          )
        }.to raise_error(ArgumentError, 'Invalid redaction state')
      end
    end
  end

  describe '.unredact_answer' do
    before do
      RedactionService.redact_answer(
        answer: answer,
        moderator: moderator,
        reason: 'test'
      )
    end

    it 'restores the answer successfully' do
      result = RedactionService.unredact_answer(
        answer: answer,
        moderator: staff
      )

      expect(result).to be true
      answer.reload
      expect(answer.redaction_state).to eq('visible')
      expect(answer.body).to eq('Original answer content')
      expect(answer.redacted_by).to be_nil
    end

    it 'creates an audit log entry' do
      expect {
        RedactionService.unredact_answer(
          answer: answer,
          moderator: moderator
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq('answer_unredacted')
    end

    it 'returns false when the restore update fails' do
      allow(answer).to receive(:visible?).and_return(false)
      allow(answer).to receive(:redacted_body).and_return('stored')
      allow(answer).to receive(:body).and_return('stored')
      allow(answer).to receive(:update!).and_raise(StandardError, 'db error')

      expect(
        RedactionService.unredact_answer(
          answer: answer,
          moderator: moderator
        )
      ).to be(false)
    end

    context 'when user lacks moderation privileges' do
      it 'raises ArgumentError' do
        expect {
          RedactionService.unredact_answer(
            answer: answer,
            moderator: student
          )
        }.to raise_error(ArgumentError, 'Moderator must have moderation privileges')
      end
    end

    context 'when answer is not redacted' do
      let(:visible_answer) { create(:answer, user: student) }

      it 'raises ArgumentError' do
        expect {
          RedactionService.unredact_answer(
            answer: visible_answer,
            moderator: moderator
          )
        }.to raise_error(ArgumentError, 'Answer is not redacted')
      end
    end
  end

  describe '.placeholder_text' do
    it 'returns an empty string for unknown states' do
      expect(described_class.send(:placeholder_text, :unknown)).to eq('')
    end
  end
end
