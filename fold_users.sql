--create view users as
    select case type
        when 'user-registered' then (payload->>'name', null, true)
        when 'user-changed-password' then (null, payload->>'activation_token', true)
        when 'user-banned' then (null, null, false)
    end from es.events where topic = 'users'
;

drop table es.users;
create table es.users(name, activation_token) as values
    ('john', '1234')
;
