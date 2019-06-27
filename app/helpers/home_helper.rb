module HomeHelper 

	def seperate_posts(posts)
		hn_posts = []
		sd_posts = []
		reddit_posts = []
		posts.each do |post|
			case post.site
			when 'HACKER_NEWS'
				hn_posts.push post
			when 'SLASHDOT'
				sd_posts.push post
			when 'REDDIT'
				reddit_posts.push post
			end
		end

		return hn_posts, sd_posts, reddit_posts
	end

	def read_from_database?
		post = Post.first

		return false if post.nil?

		update_time = post.created_at
		time_since_update = Time.now - update_time

		puts "------------------------------"
		puts "Time since last update: #{time_since_update} seconds."
		puts "------------------------------"

		return time_since_update < 600 # 10 minutes
	end

end