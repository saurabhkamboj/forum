# Notes

## Things to remember

- Routes
- Use special route for 404
- Use before and after filters
- View templates
- Use layouts
- Use the params
- Use helpers and view helpers
- Use validations and flash messages
- Secure the application
- Add tests

## To do

### Reading

- Read the input validation pages, [you'll find them here](https://launchschool.com/lessons/9230c94c/assignments/b47401cd)
- Read about `configure`, and `SecureRandom`.
- How to provide instructions for creating a database and loading the database dump?

### Project

- Add `ON DELETE` clause on line 8 in schema.sql - Done
- Change `ON DELETE` clause on line 17 in schema.sql - Done
- Add setup and teardown methods in forum_test.rb - Done

## Start steps

### Getting started

  1. Setup .gitignore
  2. Setup gemfile
  3. Setup application

### Design database

- A forum has posts, comments, and users. It can also have likes. Our entities are a post, comment, user, and maybe likes of a user.
  - A user can have many posts but a post can only be by one user.
  - A post and user can have many comments, but a comment can only belong to one post and user.

- Attributes:
  
  - User > id (P), username, password
  - Post > id (P), user_id (FK), text, posted_on
  - Comment > id (P), post_id (FK), user_id (FK), test, posted_on

### Setup layout and views

- Add layout.erb
- Add stylsheets
- Add index.erb

### Setup user sign-in

- Create routes
- Create signin.erb
- Write testcases

## Next steps

### Create a post

- Add href attribute to index, link it to '/new'
- Add route to '/new'
  - Should I add validation for content?
- Create new.erb
- Write testcases

### See latest posts on index

- Add `all_posts` to `database_persistence`
- Add rendering code to index.erb
- Add pagination
- Redirect if page invalid

### View a post

- If post by user, update or delete
- Add comment
- See existing comments
  - If comment by user, update or delete

### View all posts by user on profile

- Render latest posts
