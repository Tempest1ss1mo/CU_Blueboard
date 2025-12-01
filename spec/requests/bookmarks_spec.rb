require 'rails_helper'

RSpec.describe "Bookmarks", type: :request do
  let(:user) { create(:user) }
  let(:post_record) { create(:post) }

  describe "POST /posts/:id/bookmark" do
    context "when signed in" do
      before { sign_in user }

      it "creates a bookmark" do
        expect {
          post bookmark_post_path(post_record)
        }.to change(Bookmark, :count).by(1)
      end

      it "redirects back with success notice" do
        post bookmark_post_path(post_record), headers: { 'HTTP_REFERER' => post_path(post_record) }
        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('Post bookmarked')
      end

      it "marks the post as bookmarked by the user" do
        post bookmark_post_path(post_record)
        expect(post_record.bookmarked_by?(user)).to be true
      end

      it "does not allow duplicate bookmarks" do
        create(:bookmark, user: user, post: post_record)

        expect {
          post bookmark_post_path(post_record)
        }.not_to change(Bookmark, :count)
      end
    end

    context "when not signed in" do
      it "requires authentication" do
        post bookmark_post_path(post_record)
        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not create a bookmark" do
        expect {
          post bookmark_post_path(post_record)
        }.not_to change(Bookmark, :count)
      end
    end
  end

  describe "DELETE /posts/:id/unbookmark" do
    context "when signed in" do
      before { sign_in user }

      context "when bookmark exists" do
        before { create(:bookmark, user: user, post: post_record) }

        it "removes the bookmark" do
          expect {
            delete unbookmark_post_path(post_record)
          }.to change(Bookmark, :count).by(-1)
        end

        it "redirects back with success notice" do
          delete unbookmark_post_path(post_record), headers: { 'HTTP_REFERER' => post_path(post_record) }
          expect(response).to redirect_to(post_path(post_record))
          follow_redirect!
          expect(response.body).to include('Bookmark removed')
        end

        it "marks the post as no longer bookmarked by the user" do
          delete unbookmark_post_path(post_record)
          expect(post_record.bookmarked_by?(user)).to be false
        end
      end

      context "when bookmark does not exist" do
        it "does not change bookmark count" do
          expect {
            delete unbookmark_post_path(post_record)
          }.not_to change(Bookmark, :count)
        end
      end
    end

    context "when not signed in" do
      before { create(:bookmark, user: user, post: post_record) }

      it "requires authentication" do
        delete unbookmark_post_path(post_record)
        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not remove the bookmark" do
        expect {
          delete unbookmark_post_path(post_record)
        }.not_to change(Bookmark, :count)
      end
    end
  end

  describe "GET /posts/bookmarked" do
    context "when signed in" do
      before { sign_in user }

      it "returns success" do
        get bookmarked_posts_path
        expect(response).to have_http_status(:success)
      end

      it "shows bookmarked posts" do
        bookmarked_post = create(:post, title: "Bookmarked Post Title")
        create(:bookmark, user: user, post: bookmarked_post)

        get bookmarked_posts_path
        expect(response.body).to include("Bookmarked Post Title")
      end

      it "does not show non-bookmarked posts" do
        non_bookmarked_post = create(:post, title: "Non-Bookmarked Post Title")

        get bookmarked_posts_path
        expect(response.body).not_to include("Non-Bookmarked Post Title")
      end

      it "shows empty state when no bookmarks" do
        get bookmarked_posts_path
        expect(response.body).to include("You have not bookmarked any posts yet")
      end

      it "shows the Bookmarked Posts heading" do
        get bookmarked_posts_path
        expect(response.body).to include("Bookmarked Posts")
      end
    end

    context "when not signed in" do
      it "requires authentication" do
        get bookmarked_posts_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
