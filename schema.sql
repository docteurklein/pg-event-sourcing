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

create or replace function es.trigger_project() returns trigger language plpgsql as $$
begin
    perform es.project(new);
    return null;
end;
$$;

create or replace function es.project(event es.events) returns void
language plpgsql as $$
begin
    case event.type
        when 'user_registered' then
            insert into es.active_users
            (user_id            ,  name                   ,  sha256                   ,  updated_at) values
            (event.aggregate_id ,  event.payload->>'name' ,  event.payload->>'sha256' ,  event.added_at);
        when 'user_changed_password' then
            update es.active_users set
            sha256 = event.payload->>'sha256',
            updated_at = event.added_at
            where user_id = event.aggregate_id;
        when 'user_banned' then
            delete from es.active_users
            where user_id = event.aggregate_id;
        else
            raise notice 'no case for event "%"', event.type;
    end case;
end;
$$;

create trigger on_event_insert after insert on es.events
for each row execute function es.trigger_project();

commit;
