require 'pg'

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: 'forum')
    @logger = logger
    setup_schema
  end

  def query(statement, *params)
    @logger.info statement + (params.empty? ? '' : ": #{params}")
    @db.exec_params(statement, params)
  end

  def find_user(username)
    sql = "SELECT * FROM users WHERE username = $1"
    query(sql, username).first
  end

  def create_post(username, title, content)
    sql = <<~SQL
      INSERT INTO posts (username, title, content)
        VALUES ($1, $2, $3)
        RETURNING id
    SQL

    query(sql, username, title, content)
  end

  def all_posts(offset, limit)
    sql = <<~SQL
      SELECT posts.*, count(comments.id)
        FROM posts LEFT JOIN comments
          ON posts.id = comments.post_id
        GROUP BY posts.id
        ORDER BY count(comments.id) DESC, posts.created_on DESC
        OFFSET $1
        LIMIT $2
    SQL

    query(sql, offset, limit).map.with_index do |tuple, index|
      { id: tuple['id'].to_i,
        username: tuple['username'],
        title: tuple['title'],
        created_on: tuple['created_on'],
        comments: tuple['count'].to_i,
        order: offset + index + 1 }
    end
  end

  def all_posts_ids
    sql = "SELECT id FROM posts"
    query(sql).map { |tuple| tuple['id'].to_i }
  end

  def all_posts_count
    sql = "SELECT count(id) FROM posts"
    query(sql).first['count'].to_i
  end

  def find_post(post_id)
    sql = <<~SQL
      SELECT * FROM posts
        WHERE id = $1
    SQL
    tuple = query(sql, post_id).first

    { username: tuple['username'],
      title: tuple['title'],
      content: tuple['content'],
      created_on: tuple['created_on'],
      comments: count_comments(post_id) }
  end

  def edit_post(post_id, content)
    sql = "UPDATE posts SET content = $1 WHERE id = $2"
    query(sql, content, post_id)
  end

  def delete_post(post_id)
    sql = "DELETE FROM posts WHERE id = $1"
    query(sql, post_id)
  end

  def add_comment(post_id, username, content)
    sql = <<~SQL
      INSERT INTO comments (post_id, username, content)
        VALUES ($1, $2, $3)
    SQL

    query(sql, post_id, username, content)
  end

  def comments_on_post(post_id, offset, limit)
    sql = <<~SQL
      SELECT * FROM comments
        WHERE post_id = $1
        ORDER BY id DESC
        OFFSET $2
        LIMIT $3
    SQL

    query(sql, post_id, offset, limit).map do |tuple|
      { id: tuple['id'].to_i,
        username: tuple['username'],
        content: tuple['content'],
        created_on: tuple['created_on'] }
    end
  end

  def find_comment(comment_id)
    sql = "SELECT * FROM comments WHERE id = $1"
    tuple = query(sql, comment_id).first

    { id: tuple['id'],
      post_id: tuple['post_id'],
      username: tuple['username'],
      content: tuple['content'],
      created_on: tuple['created_on'] }
  end

  def all_comment_ids
    sql = "SELECT id FROM comments"
    query(sql).map { |tuple| tuple['id'].to_i }
  end

  def edit_comment(comment_id, content)
    sql = "UPDATE comments SET content = $1 WHERE id = $2"
    query(sql, content, comment_id)
  end

  def delete_comment(comment_id)
    sql = "DELETE FROM comments WHERE id = $1"
    query(sql, comment_id)
  end

  def all_posts_by_user(username, offset, limit)
    sql = <<~SQL
      SELECT * FROM posts
        WHERE username = $1
        ORDER BY created_on DESC
        OFFSET $2
        LIMIT $3
    SQL

    query(sql, username, offset, limit).map do |tuple|
      post_id = tuple['id'].to_i

      { id: post_id,
        title: tuple['title'],
        created_on: tuple['created_on'],
        comments: count_comments(post_id) }
    end
  end

  def count_of_posts_by_user(username)
    sql = "SELECT count(id) FROM posts WHERE username = $1"
    query(sql, username).first['count'].to_i
  end

  private

  def count_comments(post_id)
    sql = "SELECT count(id) FROM comments WHERE post_id = $1"
    query(sql, post_id).first['count'].to_i
  end

  def setup_schema
    result = @db.exec <<~SQL
      SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users';
    SQL

    if result[0]['count'] == "0"
      @db.exec <<~SQL
        CREATE TABLE users (
          username varchar(100) PRIMARY KEY,
          password text UNIQUE NOT NULL
        );

        CREATE TABLE posts (
          id serial PRIMARY KEY,
          username text NOT NULL REFERENCES users(username) ON DELETE CASCADE,
          title varchar(100) NOT NULL,
          content text NOT NULL,
          created_on timestamp NOT NULL DEFAULT NOW()
        );

        CREATE TABLE comments (
          id serial PRIMARY KEY,
          post_id int NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
          username text NOT NULL REFERENCES users(username) ON DELETE CASCADE,
          content text NOT NULL,
          created_on timestamp NOT NULL DEFAULT NOW()
        );

        INSERT INTO users
          VALUES ('tech_guru', '$2a$12$kmhLiw.1D/aG0Rk3mYgaY.HjKp7VXBWE6yxHV9l00g4g.sN.FS132'),
            ('coder123', '$2a$12$NWxG82ezo.Ck5f91hvkKyO0gQOl7zxzFg3k0L8API9NQvYzpwmMjW'),
            ('nature_lover', '$2a$12$.mp6qTJAWtVvJCGtfqCSP.BPqx6nKFmcF.BctLvDkAuuhyZnzRIYm'),
            ('foodie_jane', '$2a$12$mt4YMAyxlG2KgkAjEfD52OlDNH9kDMmRVELzBmEBzVe5wV4ToJyKy');
      SQL
    end
  end
end
