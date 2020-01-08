begin;

drop schema if exists es cascade;
create schema es;

create extension if not exists "uuid-ossp" schema es;

create table es.event (
    event_id uuid primary key default uuid_generate_v4(),
    caused_by uuid references es.event (event_id),
    correlation_id uuid,
    aggregate_id uuid not null,
    type text not null,
    topic text not null,
    added_at timestamptz not null default clock_timestamp(),
    payload jsonb not null,
    occ_version bigint not null unique
);
create index on es.event (aggregate_id);

create rule immutable_event as on update to es.event do instead nothing;
create rule immortal_event as on delete to es.event do instead nothing;

create table es.user (
    user_id uuid primary key,
    name text not null,
    sha256 text,
    updated_at timestamptz not null
);

create table es.product (
    product_id uuid primary key,
    name text not null,
    updated_at timestamptz not null
);

create table es.sale (
    user_id uuid references es.user (user_id) on delete cascade,
    product_id uuid references es.product (product_id) on delete cascade,
    at timestamptz not null
);

create table es.search (
    aggregate_id uuid primary key,
    type text not null,
    content tsvector not null
);

create function es.project(event es.event) returns void
language plpgsql as $$
begin
    case event.type
        when 'user_registered' then
            insert into es.user
            (user_id            ,  name                   ,  sha256                   ,  updated_at) values
            (event.aggregate_id ,  event.payload->>'name' ,  event.payload->>'sha256' ,  event.added_at);

            insert into es.search
            (aggregate_id, type, content) values
            (event.aggregate_id, event.topic, to_tsvector('english', event.payload));

        when 'user_changed_password' then
            update es.user set
            sha256 = event.payload->>'sha256',
            updated_at = event.added_at
            where user_id = event.aggregate_id;

        when 'user_banned' then
            delete from es.user
            where user_id = event.aggregate_id;

            delete from es.search
            where aggregate_id = event.aggregate_id;

        when 'product_added' then
            insert into es.product
            (product_id         ,  name                   ,  updated_at) values
            (event.aggregate_id ,  event.payload->>'name' ,  event.added_at);

            insert into es.search
            (aggregate_id, type, content) values
            (event.aggregate_id, event.topic, to_tsvector('english', event.payload));

        when 'product_bought' then
            insert into es.sale
            (user_id            ,  product_id                           ,  at) values
            (event.aggregate_id ,  (event.payload->>'product_id')::uuid ,  event.added_at);

        else
            raise notice 'no case for event "%"', event.type;
    end case;
end;
$$;

create function es.trigger_project() returns trigger language plpgsql as $$
begin
    perform es.project(new);
    return null;
end;
$$;

create trigger on_event_insert after insert on es.event
for each row execute function es.trigger_project();

commit;
