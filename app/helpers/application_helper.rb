module ApplicationHelper
  def streak_emoji(streak)
    case streak
    when 1    then "🐢"
    when 2..3 then "🌱"
    when 4..9 then "⚡"
    else
      fires = [streak / 10, 3].min
      "🔥" * fires
    end
  end
end
