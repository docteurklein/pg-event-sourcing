begin;

select uuid_generate_v4() as user_1 \gset
select uuid_generate_v4() as user_2 \gset
select uuid_generate_v4() as user_3 \gset

truncate es.events;
truncate es.active_users;

insert into es.events
    (aggregate_id ,  added_at                 ,  type                    ,  topic   ,  payload) values
    (:'user_1'      ,  now() + interval '1 day' ,  'user_registered'       ,  'users' ,  '{"name": "john"}'),
    (:'user_1'      ,  now() + interval '2 day' ,  'user_changed_password' ,  'users' ,  '{"sha256": "f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2"}'),
    (:'user_2'      ,  now() + interval '3 day' ,  'user_registered'       ,  'users' ,  '{"name": "bob"}'),
    (:'user_2'      ,  now() + interval '5 day' ,  'user_banned'           ,  'users' ,  '{"reason": "fail"}'),
    (:'user_3'      ,  now() + interval '6 day' ,  'user_registered'       ,  'users' ,  '{"name": "alice"}')
;
commit;

select * from es.active_users;
