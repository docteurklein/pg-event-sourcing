begin;

drop schema if exists es cascade;
create schema es;

create extension if not exists "uuid-ossp" schema es;

create table es.events (
    event_id uuid primary key default uuid_generate_v4(),
    aggregate_id uuid not null,
    type text not null,
    topic text not null,
    added_at timestamptz not null default clock_timestamp(),
    payload jsonb not null
);

create rule immutable_events as on update to es.events do instead nothing;
create rule immortal_events as on delete to es.events do instead nothing;

create table es.active_users (
    user_id uuid primary key,
    name text not null,
    sha256 text,
    updated_at timestamptz not null
);

create rule user_registered as on insert to es.events
where type = 'user_registered' do also
insert into es.active_users
(user_id          ,  name                 ,  sha256                 ,  updated_at) values
(new.aggregate_id ,  new.payload->>'name' ,  new.payload->>'sha256' ,  new.added_at);

create rule user_changed_password as on insert to es.events
where type = 'user_changed_password' do also
update es.active_users set
sha256 = new.payload->>'sha256',
updated_at = new.added_at
where user_id = new.aggregate_id;

create rule user_banned as on insert to es.events
where type = 'user_banned' do also
delete from es.active_users
where user_id = new.aggregate_id;

commit;
