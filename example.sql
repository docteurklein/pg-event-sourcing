abort;
\i schema.sql
begin transaction isolation level serializable;

select uuid_generate_v4() as user_1 \gset
select uuid_generate_v4() as user_2 \gset
select uuid_generate_v4() as user_3 \gset
select uuid_generate_v4() as product_1 \gset
select uuid_generate_v4() as product_2 \gset

truncate es.event cascade;
truncate es.user cascade;
truncate es.product cascade;

insert into es.event
(occ_version ,  aggregate_id ,  added_at                 ,  type                    ,  topic      ,  payload) values
(1           ,  :'user_1'    ,  now() + interval '1 day' ,  'user_registered'       ,  'users'    ,  '{"name": "john"}'),
(2           ,  :'user_1'    ,  now() + interval '2 day' ,  'user_changed_password' ,  'users'    ,  '{"sha256": "f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2"}'),
(3           ,  :'user_2'    ,  now() + interval '3 day' ,  'user_registered'       ,  'users'    ,  '{"name": "bob"}'),
(4           ,  :'user_2'    ,  now() + interval '5 day' ,  'user_banned'           ,  'users'    ,  '{"reason": "fail"}'),
(5           ,  :'user_3'    ,  now() + interval '6 day' ,  'user_registered'       ,  'users'    ,  '{"name": "alice"}'),
(6           ,  :'product_1' ,  now() + interval '6 day' ,  'product_added'         ,  'products' ,  '{"name": "laptop","type": "electronics"}'),
(7           ,  :'product_2' ,  now() + interval '6 day' ,  'product_added'         ,  'products' ,  '{"name": "shoe","type": "mode"}'),
(8           ,  :'user_1'    ,  now() + interval '7 day' ,  'product_bought'        ,  'sales'    ,  jsonb_build_object(
    'user_id',:'user_1',
    'product_id', :'product_1'
));

with latest as (
    select occ_version from es.event order by occ_version desc limit 1
)
insert into es.event
(occ_version           ,  aggregate_id ,  added_at                 ,  type             ,  topic   ,  payload) select
latest.occ_version + 1 ,  :'user_1'    ,  now() + interval '7 day' ,  'product_bought' ,  'sales' ,  jsonb_build_object(
    'user_id',:'user_1',
    'product_id',:'product_1'
)
from latest;

commit;
