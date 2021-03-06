module Scraper
	require 'open-uri'
	include HnHelper

	HN_URL = 'https://news.ycombinator.com'
	SD_URL = 'https://slashdot.org'
	REDDIT_URL = 'https://www.reddit.com/r/programming/.json'

	TYPE = {
		HN: 'HACKER_NEWS',
		REDDIT: 'REDDIT',
		SD: 'SLASHDOT'
	}

	def fetch_posts
    Post.delete_all

		hn_posts = get_hn_posts
		sd_posts = get_sd_posts
		reddit_posts = get_reddit_posts

		posts = hn_posts + sd_posts + reddit_posts

		posts.each do |post|
			begin
				post.save
			rescue 
				puts 'cannot load post.'
			end
		end

		return hn_posts, sd_posts, reddit_posts
	end

	private 

		def get_hn_posts
			doc = Nokogiri::HTML(open(HN_URL), nil, Encoding::UTF_8.to_s)
			posts = []

			raw_articles = doc.css('.athing').to_a
      raw_scores = doc.css('span.score').to_a
      raw_comments = doc.css('td.subtext a').to_a

      valid_articles = raw_articles.select(&method(:valid_post?))

      titles = valid_articles.map(&method(:extract_title))
      article_urls = valid_articles.map(&method(:get_article_link))
      scores = raw_scores.map { |score| score.inner_text.split(' ')[0] }

      comments = raw_comments.select(&method(:comment?))
      comment_counts = comments.map(&:inner_text)
      												 .map(&method(:extract_comment_count))
      hn_urls = comments.map { |c| form_hn_link c[:href]  }

      domains = article_urls.map(&method(:extract_domain))

      titles.each_with_index do |title, index|
      	post = Post.new
      	post.title = title
      	post.article_url = article_urls[index]
      	post.comments_url = hn_urls[index]
      	post.domain = domains[index]
      	post.score = scores[index]
      	post.comment_count = comment_counts[index]
      	post.site = TYPE[:HN]

      	posts.push post
      end

      return posts
		end

		def get_sd_posts
			doc = Nokogiri::HTML(open(SD_URL))
			posts = []

			headers = doc.css('.story-title a')
	    comments = doc.css('.comment-bubble')
	    summaries_raw = doc.css('.p')

	    titles = []
	    domains = []
	    comment_counts = []
	    sd_urls = []
	    summaries = [] 
	    article_urls = []

	    last = :domain
	    headers.each do |header|
	      if header[:class] == 'story-sourcelnk'
	        domains.push header.inner_text
	        article_urls.push header[:href]
	        last = :domain
	      else 
	        if last == :title
	          domains.push(' ')
	          article_urls.push(' ')
	        end
	        titles.push header.inner_text
	        sd_urls.push header[:href]
	        last = :title
	      end
	    end

	    comments.each do |comment|
	      comment_counts.push comment.children[0].inner_text
	    end

	    while comment_counts.length < 15
	      comment_counts.prepend 0
	    end

	    summaries_raw.each do |summary|
	      html = summary.children.to_s
	      if html[-12..-1].include? '<br>'
	        html = html[0...-12]
	      end
	      summaries.push html
	    end

	    titles.each_with_index do |title, index|
				post = Post.new
				post.title = title
				post.comment_count = comment_counts[index]
				post.article_url = article_urls[index]
				post.comments_url = sd_urls[index]
				post.domain = domains[index]
				post.summary = summaries[index]
				post.site = TYPE[:SD]
	      
	      posts.push post
	    end

	    return posts
		end

		def get_reddit_posts
			doc = HTTParty.get(REDDIT_URL, headers: { 'User-Agent' => 'hackrdot' })
			coder = HTMLEntities.new
			posts = []

			content = JSON.parse doc.to_s, symbolize_names: true 

      25.times do |i|
        data = content[:data][:children][i][:data]

        post = Post.new
        post.title = coder.decode(data[:title])
        post.comment_count = data[:num_comments]
        post.article_url = data[:url]
        post.comments_url = "https://reddit.com#{data[:permalink]}"
        post.domain = data[:domain]
        post.score = data[:ups]
        post.site = TYPE[:REDDIT]

        posts.push post
      end

      return posts
		end

end