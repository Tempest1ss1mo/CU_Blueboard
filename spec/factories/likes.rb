FactoryBot.define do
  factory :like do
    association :post
    association :user
    vote_type { Like::UPVOTE }

    trait :upvote do
      vote_type { Like::UPVOTE }
    end

    trait :downvote do
      vote_type { Like::DOWNVOTE }
    end
  end
end
