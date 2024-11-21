# Forum

Forum uses a simple database dseign consisting of 2 entities, post and comment. Users can create many posts & add many comments, and interact with other users.

## Details

- The application uses ruby version `3.2.2`.
- It was tested on `Firefox` version `132.0.2`.
- PostgreSQL `14.13` has been used to create the database.

## Install

Bundler has been used for dependency management. To begin with, run `bundle install` to install gems specified in the `Gemfile`.

  ```zsh
  bundle install
  ```

If you face any problem, delete `Gemfile.lock` and run `bundle install` again.

## Run

> Make sure to follow the commands in order

To configure the application, create the `forum` database. Do so by running the following command in your terminal:

```zsh
createdb forum
```

To run the application, start the server. Do so by running the following command in your terminal:

```zsh
ruby forum.rb
```

Open the connection using the url in returned log. You will be redirected to `/users/signin`. Use any of the given `username` and `password` combinations to signin:

```txt
 username     | password                           
--------------+--------------
 tech_guru    | password
 coder123     | password
 nature_lover | password
 foodie_jane  | password
```

The required schema is created using `DatabasePersistence#setup_schema`. It is called when the application is run. To insert sample data from `sample_data.sql` (the data has been auto-generated) use the following command:

```zsh
psql forum < sample_data.sql
```

## More

To add a new user, add a row to the `users` table. Do so by running the following command in the `psql` client (connect to the `forum` database):

```sql
INSERT INTO users VALUES ([username], [password]);
```

Replace '[username]' and '[password]' with values of your choice. The application will require a hashed password, `BCrpyt` gem can be used to generate one. To generate a hashed password run the following expression in an irb session:

```ruby
require 'BCrypt'
BCrypt::Password.create([password])
```

Replace '[password]' with the password of your choice.
