require 'rails_helper'

RSpec.describe Like, type: :model do
  it 'is valid with unique user and post combination' do
    like = build(:like)
    expect(like).to be_valid
  end

  it 'is invalid if the same user likes the same post twice' do
    user = create(:user)
    post = create(:post, user: user)
    create(:like, user: user, post: post)

    duplicate_like = build(:like, user: user, post: post)
    expect(duplicate_like).not_to be_valid
    expect(duplicate_like.errors[:user_id]).to include('has already been taken')
  end

  describe '#find_like_by and #liked_by?' do
    it 'detects when a user has liked a post' do
      user = create(:user)
      post = create(:post)
      create(:like, user: user, post: post)

      expect(post.liked_by?(user)).to be true
      expect(post.find_like_by(user)).to be_a(Like)
    end

    it 'returns false/nil when a user has not liked the post' do
      user = create(:user)
      post = create(:post)

      expect(post.liked_by?(user)).to be false
      expect(post.find_like_by(user)).to be_nil
    end
  end

  describe '#upvote?' do
    it 'returns true for upvote' do
      like = build(:like, :upvote)
      expect(like.upvote?).to be true
    end

    it 'returns false for downvote' do
      like = build(:like, :downvote)
      expect(like.upvote?).to be false
    end
  end

  describe '#downvote?' do
    it 'returns true for downvote' do
      like = build(:like, :downvote)
      expect(like.downvote?).to be true
    end

    it 'returns false for upvote' do
      like = build(:like, :upvote)
      expect(like.downvote?).to be false
    end
  end

  describe 'scopes' do
    let(:post_record) { create(:post) }
    let!(:upvote1) { create(:like, :upvote, post: post_record) }
    let!(:upvote2) { create(:like, :upvote, post: post_record) }
    let!(:downvote1) { create(:like, :downvote, post: post_record) }

    describe '.upvotes' do
      it 'returns only upvotes' do
        expect(post_record.likes.upvotes.count).to eq(2)
        expect(post_record.likes.upvotes).to include(upvote1, upvote2)
        expect(post_record.likes.upvotes).not_to include(downvote1)
      end
    end

    describe '.downvotes' do
      it 'returns only downvotes' do
        expect(post_record.likes.downvotes.count).to eq(1)
        expect(post_record.likes.downvotes).to include(downvote1)
        expect(post_record.likes.downvotes).not_to include(upvote1, upvote2)
      end
    end
  end
end
