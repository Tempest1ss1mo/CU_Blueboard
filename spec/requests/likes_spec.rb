require 'rails_helper'

RSpec.describe "Likes", type: :request do
  let(:user) { create(:user) }
  let(:post_record) { create(:post) }

  describe "POST /posts/:post_id/likes" do
    context "when signed in" do
      it "creates a like" do
        sign_in user

        expect {
          post post_likes_path(post_record)
        }.to change(Like, :count).by(1)

        expect(response).to redirect_to(post_path(post_record))
      end

      it "allows a user to like a post" do
        sign_in user
        post post_likes_path(post_record)

        expect(post_record.liked_by?(user)).to be true
      end
    end

    context "when not signed in" do
      it "requires authentication" do
        post post_likes_path(post_record)

        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not create a like" do
        expect {
          post post_likes_path(post_record)
        }.not_to change(Like, :count)
      end
    end
  end

  describe "DELETE /posts/:post_id/likes/:id" do
    let!(:like) { create(:like, user: user, post: post_record) }

    context "when signed in as the like owner" do
      it "removes the like" do
        sign_in user

        expect {
          delete post_like_path(post_record, like)
        }.to change(Like, :count).by(-1)

        expect(response).to redirect_to(post_path(post_record))
      end

      it "makes the post no longer liked by the user" do
        sign_in user
        delete post_like_path(post_record, like)

        expect(post_record.liked_by?(user)).to be false
      end

      it "ignores redundant delete requests once the like is gone" do
        sign_in user
        delete post_like_path(post_record, like)

        expect {
          delete post_like_path(post_record, like)
        }.not_to change(Like, :count)

        expect(response).to redirect_to(post_path(post_record))
      end
    end

    context "when not signed in" do
      it "requires authentication" do
        delete post_like_path(post_record, like)

        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not remove the like" do
        expect {
          delete post_like_path(post_record, like)
        }.not_to change(Like, :count)
      end
    end
  end

  describe "POST /posts/:post_id/upvote" do
    before { sign_in user }

    context "when no existing vote" do
      it "creates an upvote" do
        expect {
          post upvote_post_path(post_record)
        }.to change { post_record.likes.upvotes.count }.by(1)

        expect(response).to redirect_to(post_path(post_record))
      end
    end

    context "when already upvoted (toggle off)" do
      before { create(:like, :upvote, user: user, post: post_record) }

      it "removes the upvote" do
        expect {
          post upvote_post_path(post_record)
        }.to change { post_record.likes.count }.by(-1)
      end
    end

    context "when already downvoted (switch to upvote)" do
      before { create(:like, :downvote, user: user, post: post_record) }

      it "switches to upvote" do
        post upvote_post_path(post_record)
        expect(post_record.find_vote_by(user).upvote?).to be true
      end
    end
  end

  describe "POST /posts/:post_id/downvote" do
    before { sign_in user }

    context "when no existing vote" do
      it "creates a downvote" do
        expect {
          post downvote_post_path(post_record)
        }.to change { post_record.likes.downvotes.count }.by(1)

        expect(response).to redirect_to(post_path(post_record))
      end
    end

    context "when already downvoted (toggle off)" do
      before { create(:like, :downvote, user: user, post: post_record) }

      it "removes the downvote" do
        expect {
          post downvote_post_path(post_record)
        }.to change { post_record.likes.count }.by(-1)
      end
    end

    context "when already upvoted (switch to downvote)" do
      before { create(:like, :upvote, user: user, post: post_record) }

      it "switches to downvote" do
        post downvote_post_path(post_record)
        expect(post_record.find_vote_by(user).downvote?).to be true
      end
    end

    context "when not signed in" do
      before { sign_out user }

      it "requires authentication" do
        post downvote_post_path(post_record)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
