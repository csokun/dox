set search_path=dox;
drop function if exists save(varchar, jsonb,text[],varchar);
create function save(
	collection varchar, 
	doc jsonb, 
	search text[] = array['name','email','first','first_name','last','last_name','description','title','city','state','address','street', 'company'],
	schema varchar default 'public', 
	out res jsonb
)
as $$

declare
	doc_id int := doc -> 'id';
	saved record;
	saved_doc jsonb;
	search_key varchar;
	search_params varchar;
begin
	

	-- make sure the table exists
	perform dox.create_collection(collection => collection, schema => schema);
	

	if (jsonb_exists(doc, 'id')) then

		execute format('insert into %s.%s (id, body) 
										values (%L, %L) 
										on conflict (id)
										do update set body = excluded.body, updated_at = now()
										returning *',schema,collection, doc -> 'id', doc) into saved;
    res := saved.body;
	else
		-- there's no document id
		execute format('insert into %s.%s (body) values (%L) returning *',schema,collection, doc) into saved;

		-- this will have an id on it

		select(doc || format('{"id": %s}', saved.id::text)::jsonb) into res;
		execute format('update %s.%s set body=%L, updated_at = now() where id=%s',schema,collection,res,saved.id);

	end if;


	-- do it automatically MMMMMKKK?
	foreach search_key in array search
	loop
		if(jsonb_exists(res, search_key)) then
			search_params :=  concat(search_params,' ',res ->> search_key);
		end if;
	end loop;
	if search_params is not null then
		execute format('update %s.%s set search=to_tsvector(%L) where id=%s',schema,collection,search_params,saved.id);
	end if;

end;

$$ language plpgsql;