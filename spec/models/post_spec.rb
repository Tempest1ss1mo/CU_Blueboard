require 'rails_helper'

RSpec.describe Post, type: :model do
  it 'is valid with valid attributes' do
    post = build(:post)
    expect(post).to be_valid
  end

  it 'is invalid without a title' do
    post = build(:post, title: nil)
    expect(post).not_to be_valid
    expect(post.errors[:title]).to include("can't be blank")
  end

  it 'is invalid without a body' do
    post = build(:post, body: nil)
    expect(post).not_to be_valid
    expect(post.errors[:body]).to include("can't be blank")
  end

  it 'is invalid without a topic' do
    post = build(:post, topic: nil)
    expect(post).not_to be_valid
    expect(post.errors[:topic]).to include("can't be blank")
  end

  it 'is invalid without a school' do
    post = build(:post, school: nil)
    expect(post).not_to be_valid
    expect(post.errors[:school]).to include("can't be blank")
  end

  it 'is invalid with an invalid school' do
    post = build(:post, school: 'Harvard')
    expect(post).not_to be_valid
    expect(post.errors[:school]).to include('is not included in the list')
  end

  it 'requires at least one tag' do
    post = build(:post)
    post.tags = []
    expect(post).not_to be_valid
    expect(post.errors[:tags]).to include('must include at least one tag')
  end

  it 'limits tags to five' do
    post = build(:post)
    extra_tags = create_list(:tag, 6)
    post.tag_ids = extra_tags.map(&:id)
    expect(post).not_to be_valid
    expect(post.errors[:tags]).to include('cannot include more than 5 tags')
  end

  it 'creates a thread identity after creation' do
    post = create(:post)

    identity = ThreadIdentity.find_by(user: post.user, post: post)
    expect(identity).to be_present
  end

  describe '#expires_at_within_window' do
    it 'allows nil expiration' do
      post = build(:post, expires_at: nil)
      expect(post).to be_valid
    end

    it 'rejects expirations shorter than 7 days' do
      post = build(:post, expires_at: 3.days.from_now)
      expect(post).not_to be_valid
      expect(post.errors[:expires_at]).to include('must be between 7 and 30 days from now')
    end

    it 'rejects expirations longer than 30 days' do
      post = build(:post, expires_at: 40.days.from_now)
      expect(post).not_to be_valid
      expect(post.errors[:expires_at]).to include('must be between 7 and 30 days from now')
    end

    it 'accepts expirations within the 7-30 day window' do
      post = build(:post, expires_at: 10.days.from_now)
      expect(post).to be_valid
    end
  end

  describe '.search' do
    let!(:matching_post) { create(:post, title: 'Housing tips', body: 'Advice on Columbia housing') }
    let!(:non_matching_post) { create(:post, title: 'Dining hall review', body: 'Food is great') }

    it 'returns posts that include the query in the title' do
      results = Post.search('housing')
      expect(results).to include(matching_post)
      expect(results).not_to include(non_matching_post)
    end

    it 'returns all posts when the query is blank' do
      expect(Post.search(nil)).to contain_exactly(matching_post, non_matching_post)
    end
  end

  describe '#lock_with' do
    it 'marks the post as solved when locking' do
      post = create(:post)
      answer = create(:answer, post: post)

      post.lock_with(answer)

      expect(post).to be_status_solved
    end

    it 'reopens the post when unlocking' do
      post = create(:post)
      answer = create(:answer, post: post)
      post.lock_with(answer)

      post.unlock!

      expect(post).to be_status_open
    end
  end

  describe 'redaction fields' do
    it 'defaults to visible' do
      post = create(:post)

      expect(post.redaction_state).to eq('visible')
    end

    it 'requires replacement content when redacted' do
      post = build(:post, redaction_state: :redacted, redacted_body: nil)

      expect(post).not_to be_valid
      expect(post.errors[:redacted_body]).to include('must be provided when content is redacted')
    end
  end

  describe '#accepted_answer_belongs_to_post' do
    it 'adds error when accepted_answer belongs to different post' do
      post = create(:post)
      other_post = create(:post)
      other_answer = create(:answer, post: other_post)

      post.accepted_answer = other_answer
      post.valid?

      expect(post.errors[:accepted_answer]).to include('must belong to this post')
    end
  end

  describe '#voted_by?' do
    let(:post_record) { create(:post) }
    let(:user) { create(:user) }

    it 'returns true when user has voted' do
      create(:like, post: post_record, user: user)
      expect(post_record.voted_by?(user)).to be true
    end

    it 'returns false when user has not voted' do
      expect(post_record.voted_by?(user)).to be false
    end

    it 'returns false for nil user' do
      expect(post_record.voted_by?(nil)).to be false
    end
  end

  describe '#find_vote_by' do
    let(:post_record) { create(:post) }
    let(:user) { create(:user) }

    it 'returns the vote when user has voted' do
      like = create(:like, post: post_record, user: user)
      expect(post_record.find_vote_by(user)).to eq(like)
    end

    it 'returns nil when user has not voted' do
      expect(post_record.find_vote_by(user)).to be_nil
    end

    it 'returns nil for nil user' do
      expect(post_record.find_vote_by(nil)).to be_nil
    end

    it 'handles hash-like user object' do
      result = post_record.find_vote_by({ id: 999 })
      expect(result).to be_nil
    end
  end

  describe '#record_revision!' do
    let(:post_record) { create(:post) }
    let(:editor) { create(:user) }

    it 'skips revision when content unchanged' do
      expect {
        post_record.record_revision!(
          editor: editor,
          previous_title: post_record.title,
          previous_body: post_record.body
        )
      }.not_to change { post_record.post_revisions.count }
    end

    it 'creates revision when title changes' do
      original_title = post_record.title
      post_record.update!(title: 'New Title')

      expect {
        post_record.record_revision!(
          editor: editor,
          previous_title: original_title,
          previous_body: post_record.body
        )
      }.to change { post_record.post_revisions.count }.by(1)
    end
  end

  describe 'vote counting' do
    let(:post_record) { create(:post) }

    before do
      create_list(:like, 3, :upvote, post: post_record)
      create_list(:like, 1, :downvote, post: post_record)
    end

    describe '#upvotes_count' do
      it 'returns the number of upvotes' do
        expect(post_record.upvotes_count).to eq(3)
      end
    end

    describe '#downvotes_count' do
      it 'returns the number of downvotes' do
        expect(post_record.downvotes_count).to eq(1)
      end
    end

    describe '#net_score' do
      it 'returns upvotes minus downvotes' do
        expect(post_record.net_score).to eq(2)
      end
    end
  end

  describe '#request_appeal!' do
    it 'sets appeal_requested to true' do
      post = create(:post, appeal_requested: false)
      post.request_appeal!
      expect(post.reload.appeal_requested).to be true
    end
  end

  describe '#clear_appeal!' do
    it 'sets appeal_requested to false' do
      post = create(:post, appeal_requested: true)
      post.clear_appeal!
      expect(post.reload.appeal_requested).to be false
    end
  end
end
