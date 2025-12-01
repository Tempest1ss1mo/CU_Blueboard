require 'rails_helper'

RSpec.describe Bookmark, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to a post' do
      association = described_class.reflect_on_association(:post)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    it 'is valid with unique user and post combination' do
      bookmark = build(:bookmark)
      expect(bookmark).to be_valid
    end

    it 'is invalid if the same user bookmarks the same post twice' do
      user = create(:user)
      post = create(:post, user: user)
      create(:bookmark, user: user, post: post)

      duplicate_bookmark = build(:bookmark, user: user, post: post)
      expect(duplicate_bookmark).not_to be_valid
      expect(duplicate_bookmark.errors[:user_id]).to include('has already bookmarked this post')
    end

    it 'allows different users to bookmark the same post' do
      post = create(:post)
      user1 = create(:user)
      user2 = create(:user)

      bookmark1 = create(:bookmark, user: user1, post: post)
      bookmark2 = build(:bookmark, user: user2, post: post)

      expect(bookmark1).to be_valid
      expect(bookmark2).to be_valid
    end

    it 'allows the same user to bookmark different posts' do
      user = create(:user)
      post1 = create(:post)
      post2 = create(:post)

      bookmark1 = create(:bookmark, user: user, post: post1)
      bookmark2 = build(:bookmark, user: user, post: post2)

      expect(bookmark1).to be_valid
      expect(bookmark2).to be_valid
    end
  end

  describe 'Post#bookmarked_by?' do
    it 'returns true when user has bookmarked the post' do
      user = create(:user)
      post = create(:post)
      create(:bookmark, user: user, post: post)

      expect(post.bookmarked_by?(user)).to be true
    end

    it 'returns false when user has not bookmarked the post' do
      user = create(:user)
      post = create(:post)

      expect(post.bookmarked_by?(user)).to be false
    end

    it 'returns false when user is nil' do
      post = create(:post)

      expect(post.bookmarked_by?(nil)).to be false
    end
  end

  describe 'User associations' do
    it 'can access bookmarked posts through user' do
      user = create(:user)
      post1 = create(:post)
      post2 = create(:post)
      create(:bookmark, user: user, post: post1)
      create(:bookmark, user: user, post: post2)

      expect(user.bookmarked_posts).to include(post1, post2)
      expect(user.bookmarked_posts.count).to eq(2)
    end

    it 'destroys bookmarks when user is destroyed' do
      user = create(:user)
      post = create(:post)
      create(:bookmark, user: user, post: post)

      expect { user.destroy }.to change(Bookmark, :count).by(-1)
    end
  end

  describe 'Post associations' do
    it 'can access users who bookmarked through post' do
      post = create(:post)
      user1 = create(:user)
      user2 = create(:user)
      create(:bookmark, user: user1, post: post)
      create(:bookmark, user: user2, post: post)

      expect(post.bookmarked_by_users).to include(user1, user2)
      expect(post.bookmarked_by_users.count).to eq(2)
    end

    it 'destroys bookmarks when post is destroyed' do
      user = create(:user)
      post = create(:post, user: user)
      create(:bookmark, user: user, post: post)

      expect { post.destroy }.to change(Bookmark, :count).by(-1)
    end
  end
end
