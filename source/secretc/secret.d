/*
 * This file is part of gtkD.
 *
 * gtkD is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version, with
 * some exceptions, please read the COPYING file.
 *
 * gtkD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with gtkD; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
 */

// generated automatically - do not change
// find conversion definition on APILookup.txt
// implement new conversion functionalities on the wrap.utils pakage


module secretc.secret;

import std.stdio;

import secretc.secrettypes;
import gtkc.Loader;
import gtkc.paths;

enum LIBRARY_SECRET = "libsecret-1.so.0";

shared static this()
{

	try {
		Linker.loadLibrary(LIBRARY_SECRET);
	} catch (Exception e) {
		stderr.writeln("Library " ~ LIBRARY_SECRET ~ " cannot be loaded, related functionality will not be available");
		return;
	}

	// secret.Collection

	Linker.link(secret_collection_get_type, "secret_collection_get_type", LIBRARY_SECRET);
	Linker.link(secret_collection_new_for_dbus_path_finish, "secret_collection_new_for_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_new_for_dbus_path_sync, "secret_collection_new_for_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_create, "secret_collection_create", LIBRARY_SECRET);
	Linker.link(secret_collection_create_finish, "secret_collection_create_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_create_sync, "secret_collection_create_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_for_alias, "secret_collection_for_alias", LIBRARY_SECRET);
	Linker.link(secret_collection_for_alias_finish, "secret_collection_for_alias_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_for_alias_sync, "secret_collection_for_alias_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_new_for_dbus_path, "secret_collection_new_for_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_collection_delete, "secret_collection_delete", LIBRARY_SECRET);
	Linker.link(secret_collection_delete_finish, "secret_collection_delete_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_delete_sync, "secret_collection_delete_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_get_created, "secret_collection_get_created", LIBRARY_SECRET);
	Linker.link(secret_collection_get_flags, "secret_collection_get_flags", LIBRARY_SECRET);
	Linker.link(secret_collection_get_items, "secret_collection_get_items", LIBRARY_SECRET);
	Linker.link(secret_collection_get_label, "secret_collection_get_label", LIBRARY_SECRET);
	Linker.link(secret_collection_get_locked, "secret_collection_get_locked", LIBRARY_SECRET);
	Linker.link(secret_collection_get_modified, "secret_collection_get_modified", LIBRARY_SECRET);
	Linker.link(secret_collection_get_service, "secret_collection_get_service", LIBRARY_SECRET);
	Linker.link(secret_collection_load_items, "secret_collection_load_items", LIBRARY_SECRET);
	Linker.link(secret_collection_load_items_finish, "secret_collection_load_items_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_load_items_sync, "secret_collection_load_items_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_refresh, "secret_collection_refresh", LIBRARY_SECRET);
	Linker.link(secret_collection_search, "secret_collection_search", LIBRARY_SECRET);
	Linker.link(secret_collection_search_finish, "secret_collection_search_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_search_for_dbus_paths, "secret_collection_search_for_dbus_paths", LIBRARY_SECRET);
	Linker.link(secret_collection_search_for_dbus_paths_finish, "secret_collection_search_for_dbus_paths_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_search_for_dbus_paths_sync, "secret_collection_search_for_dbus_paths_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_search_sync, "secret_collection_search_sync", LIBRARY_SECRET);
	Linker.link(secret_collection_set_label, "secret_collection_set_label", LIBRARY_SECRET);
	Linker.link(secret_collection_set_label_finish, "secret_collection_set_label_finish", LIBRARY_SECRET);
	Linker.link(secret_collection_set_label_sync, "secret_collection_set_label_sync", LIBRARY_SECRET);

	// secret.Item

	Linker.link(secret_item_get_type, "secret_item_get_type", LIBRARY_SECRET);
	Linker.link(secret_item_new_for_dbus_path_finish, "secret_item_new_for_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_item_new_for_dbus_path_sync, "secret_item_new_for_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_item_create, "secret_item_create", LIBRARY_SECRET);
	Linker.link(secret_item_create_finish, "secret_item_create_finish", LIBRARY_SECRET);
	Linker.link(secret_item_create_sync, "secret_item_create_sync", LIBRARY_SECRET);
	Linker.link(secret_item_load_secrets, "secret_item_load_secrets", LIBRARY_SECRET);
	Linker.link(secret_item_load_secrets_finish, "secret_item_load_secrets_finish", LIBRARY_SECRET);
	Linker.link(secret_item_load_secrets_sync, "secret_item_load_secrets_sync", LIBRARY_SECRET);
	Linker.link(secret_item_new_for_dbus_path, "secret_item_new_for_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_item_delete, "secret_item_delete", LIBRARY_SECRET);
	Linker.link(secret_item_delete_finish, "secret_item_delete_finish", LIBRARY_SECRET);
	Linker.link(secret_item_delete_sync, "secret_item_delete_sync", LIBRARY_SECRET);
	Linker.link(secret_item_get_attributes, "secret_item_get_attributes", LIBRARY_SECRET);
	Linker.link(secret_item_get_created, "secret_item_get_created", LIBRARY_SECRET);
	Linker.link(secret_item_get_flags, "secret_item_get_flags", LIBRARY_SECRET);
	Linker.link(secret_item_get_label, "secret_item_get_label", LIBRARY_SECRET);
	Linker.link(secret_item_get_locked, "secret_item_get_locked", LIBRARY_SECRET);
	Linker.link(secret_item_get_modified, "secret_item_get_modified", LIBRARY_SECRET);
	Linker.link(secret_item_get_schema_name, "secret_item_get_schema_name", LIBRARY_SECRET);
	Linker.link(secret_item_get_secret, "secret_item_get_secret", LIBRARY_SECRET);
	Linker.link(secret_item_get_service, "secret_item_get_service", LIBRARY_SECRET);
	Linker.link(secret_item_load_secret, "secret_item_load_secret", LIBRARY_SECRET);
	Linker.link(secret_item_load_secret_finish, "secret_item_load_secret_finish", LIBRARY_SECRET);
	Linker.link(secret_item_load_secret_sync, "secret_item_load_secret_sync", LIBRARY_SECRET);
	Linker.link(secret_item_refresh, "secret_item_refresh", LIBRARY_SECRET);
	Linker.link(secret_item_set_attributes, "secret_item_set_attributes", LIBRARY_SECRET);
	Linker.link(secret_item_set_attributes_finish, "secret_item_set_attributes_finish", LIBRARY_SECRET);
	Linker.link(secret_item_set_attributes_sync, "secret_item_set_attributes_sync", LIBRARY_SECRET);
	Linker.link(secret_item_set_label, "secret_item_set_label", LIBRARY_SECRET);
	Linker.link(secret_item_set_label_finish, "secret_item_set_label_finish", LIBRARY_SECRET);
	Linker.link(secret_item_set_label_sync, "secret_item_set_label_sync", LIBRARY_SECRET);
	Linker.link(secret_item_set_secret, "secret_item_set_secret", LIBRARY_SECRET);
	Linker.link(secret_item_set_secret_finish, "secret_item_set_secret_finish", LIBRARY_SECRET);
	Linker.link(secret_item_set_secret_sync, "secret_item_set_secret_sync", LIBRARY_SECRET);

	// secret.Prompt

	Linker.link(secret_prompt_get_type, "secret_prompt_get_type", LIBRARY_SECRET);
	Linker.link(secret_prompt_perform, "secret_prompt_perform", LIBRARY_SECRET);
	Linker.link(secret_prompt_perform_finish, "secret_prompt_perform_finish", LIBRARY_SECRET);
	Linker.link(secret_prompt_perform_sync, "secret_prompt_perform_sync", LIBRARY_SECRET);
	Linker.link(secret_prompt_run, "secret_prompt_run", LIBRARY_SECRET);

	// secret.Schema

	Linker.link(secret_schema_get_type, "secret_schema_get_type", LIBRARY_SECRET);
	Linker.link(secret_schema_new, "secret_schema_new", LIBRARY_SECRET);
	Linker.link(secret_schema_newv, "secret_schema_newv", LIBRARY_SECRET);
	Linker.link(secret_schema_ref, "secret_schema_ref", LIBRARY_SECRET);
	Linker.link(secret_schema_unref, "secret_schema_unref", LIBRARY_SECRET);

	// secret.SchemaAttribute

	Linker.link(secret_schema_attribute_get_type, "secret_schema_attribute_get_type", LIBRARY_SECRET);

	// secret.Service

	Linker.link(secret_service_get_type, "secret_service_get_type", LIBRARY_SECRET);
	Linker.link(secret_service_disconnect, "secret_service_disconnect", LIBRARY_SECRET);
	Linker.link(secret_service_get, "secret_service_get", LIBRARY_SECRET);
	Linker.link(secret_service_get_finish, "secret_service_get_finish", LIBRARY_SECRET);
	Linker.link(secret_service_get_sync, "secret_service_get_sync", LIBRARY_SECRET);
	Linker.link(secret_service_open, "secret_service_open", LIBRARY_SECRET);
	Linker.link(secret_service_open_finish, "secret_service_open_finish", LIBRARY_SECRET);
	Linker.link(secret_service_open_sync, "secret_service_open_sync", LIBRARY_SECRET);
	Linker.link(secret_service_clear, "secret_service_clear", LIBRARY_SECRET);
	Linker.link(secret_service_clear_finish, "secret_service_clear_finish", LIBRARY_SECRET);
	Linker.link(secret_service_clear_sync, "secret_service_clear_sync", LIBRARY_SECRET);
	Linker.link(secret_service_create_collection_dbus_path, "secret_service_create_collection_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_create_collection_dbus_path_finish, "secret_service_create_collection_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_create_collection_dbus_path_sync, "secret_service_create_collection_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_create_item_dbus_path, "secret_service_create_item_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_create_item_dbus_path_finish, "secret_service_create_item_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_create_item_dbus_path_sync, "secret_service_create_item_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_decode_dbus_secret, "secret_service_decode_dbus_secret", LIBRARY_SECRET);
	Linker.link(secret_service_delete_item_dbus_path, "secret_service_delete_item_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_delete_item_dbus_path_finish, "secret_service_delete_item_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_delete_item_dbus_path_sync, "secret_service_delete_item_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_encode_dbus_secret, "secret_service_encode_dbus_secret", LIBRARY_SECRET);
	Linker.link(secret_service_ensure_session, "secret_service_ensure_session", LIBRARY_SECRET);
	Linker.link(secret_service_ensure_session_finish, "secret_service_ensure_session_finish", LIBRARY_SECRET);
	Linker.link(secret_service_ensure_session_sync, "secret_service_ensure_session_sync", LIBRARY_SECRET);
	Linker.link(secret_service_get_collection_gtype, "secret_service_get_collection_gtype", LIBRARY_SECRET);
	Linker.link(secret_service_get_collections, "secret_service_get_collections", LIBRARY_SECRET);
	Linker.link(secret_service_get_flags, "secret_service_get_flags", LIBRARY_SECRET);
	Linker.link(secret_service_get_item_gtype, "secret_service_get_item_gtype", LIBRARY_SECRET);
	Linker.link(secret_service_get_secret_for_dbus_path, "secret_service_get_secret_for_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_get_secret_for_dbus_path_finish, "secret_service_get_secret_for_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_get_secret_for_dbus_path_sync, "secret_service_get_secret_for_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_get_secrets_for_dbus_paths, "secret_service_get_secrets_for_dbus_paths", LIBRARY_SECRET);
	Linker.link(secret_service_get_secrets_for_dbus_paths_finish, "secret_service_get_secrets_for_dbus_paths_finish", LIBRARY_SECRET);
	Linker.link(secret_service_get_secrets_for_dbus_paths_sync, "secret_service_get_secrets_for_dbus_paths_sync", LIBRARY_SECRET);
	Linker.link(secret_service_get_session_algorithms, "secret_service_get_session_algorithms", LIBRARY_SECRET);
	Linker.link(secret_service_get_session_dbus_path, "secret_service_get_session_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_load_collections, "secret_service_load_collections", LIBRARY_SECRET);
	Linker.link(secret_service_load_collections_finish, "secret_service_load_collections_finish", LIBRARY_SECRET);
	Linker.link(secret_service_load_collections_sync, "secret_service_load_collections_sync", LIBRARY_SECRET);
	Linker.link(secret_service_lock, "secret_service_lock", LIBRARY_SECRET);
	Linker.link(secret_service_lock_dbus_paths, "secret_service_lock_dbus_paths", LIBRARY_SECRET);
	Linker.link(secret_service_lock_dbus_paths_finish, "secret_service_lock_dbus_paths_finish", LIBRARY_SECRET);
	Linker.link(secret_service_lock_dbus_paths_sync, "secret_service_lock_dbus_paths_sync", LIBRARY_SECRET);
	Linker.link(secret_service_lock_finish, "secret_service_lock_finish", LIBRARY_SECRET);
	Linker.link(secret_service_lock_sync, "secret_service_lock_sync", LIBRARY_SECRET);
	Linker.link(secret_service_lookup, "secret_service_lookup", LIBRARY_SECRET);
	Linker.link(secret_service_lookup_finish, "secret_service_lookup_finish", LIBRARY_SECRET);
	Linker.link(secret_service_lookup_sync, "secret_service_lookup_sync", LIBRARY_SECRET);
	Linker.link(secret_service_prompt, "secret_service_prompt", LIBRARY_SECRET);
	Linker.link(secret_service_prompt_at_dbus_path, "secret_service_prompt_at_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_prompt_at_dbus_path_finish, "secret_service_prompt_at_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_prompt_at_dbus_path_sync, "secret_service_prompt_at_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_prompt_finish, "secret_service_prompt_finish", LIBRARY_SECRET);
	Linker.link(secret_service_prompt_sync, "secret_service_prompt_sync", LIBRARY_SECRET);
	Linker.link(secret_service_read_alias_dbus_path, "secret_service_read_alias_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_read_alias_dbus_path_finish, "secret_service_read_alias_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_read_alias_dbus_path_sync, "secret_service_read_alias_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_search, "secret_service_search", LIBRARY_SECRET);
	Linker.link(secret_service_search_finish, "secret_service_search_finish", LIBRARY_SECRET);
	Linker.link(secret_service_search_for_dbus_paths, "secret_service_search_for_dbus_paths", LIBRARY_SECRET);
	Linker.link(secret_service_search_for_dbus_paths_finish, "secret_service_search_for_dbus_paths_finish", LIBRARY_SECRET);
	Linker.link(secret_service_search_for_dbus_paths_sync, "secret_service_search_for_dbus_paths_sync", LIBRARY_SECRET);
	Linker.link(secret_service_search_sync, "secret_service_search_sync", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias, "secret_service_set_alias", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias_finish, "secret_service_set_alias_finish", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias_sync, "secret_service_set_alias_sync", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias_to_dbus_path, "secret_service_set_alias_to_dbus_path", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias_to_dbus_path_finish, "secret_service_set_alias_to_dbus_path_finish", LIBRARY_SECRET);
	Linker.link(secret_service_set_alias_to_dbus_path_sync, "secret_service_set_alias_to_dbus_path_sync", LIBRARY_SECRET);
	Linker.link(secret_service_store, "secret_service_store", LIBRARY_SECRET);
	Linker.link(secret_service_store_finish, "secret_service_store_finish", LIBRARY_SECRET);
	Linker.link(secret_service_store_sync, "secret_service_store_sync", LIBRARY_SECRET);
	Linker.link(secret_service_unlock, "secret_service_unlock", LIBRARY_SECRET);
	Linker.link(secret_service_unlock_dbus_paths, "secret_service_unlock_dbus_paths", LIBRARY_SECRET);
	Linker.link(secret_service_unlock_dbus_paths_finish, "secret_service_unlock_dbus_paths_finish", LIBRARY_SECRET);
	Linker.link(secret_service_unlock_dbus_paths_sync, "secret_service_unlock_dbus_paths_sync", LIBRARY_SECRET);
	Linker.link(secret_service_unlock_finish, "secret_service_unlock_finish", LIBRARY_SECRET);
	Linker.link(secret_service_unlock_sync, "secret_service_unlock_sync", LIBRARY_SECRET);

	// secret.Value

	Linker.link(secret_value_get_type, "secret_value_get_type", LIBRARY_SECRET);
	Linker.link(secret_value_new, "secret_value_new", LIBRARY_SECRET);
	Linker.link(secret_value_new_full, "secret_value_new_full", LIBRARY_SECRET);
	Linker.link(secret_value_get, "secret_value_get", LIBRARY_SECRET);
	Linker.link(secret_value_get_content_type, "secret_value_get_content_type", LIBRARY_SECRET);
	Linker.link(secret_value_get_text, "secret_value_get_text", LIBRARY_SECRET);
	Linker.link(secret_value_ref, "secret_value_ref", LIBRARY_SECRET);
	Linker.link(secret_value_unref, "secret_value_unref", LIBRARY_SECRET);

	// secret.Secret

	Linker.link(secret_password_clear, "secret_password_clear", LIBRARY_SECRET);
	Linker.link(secret_password_clear_finish, "secret_password_clear_finish", LIBRARY_SECRET);
	Linker.link(secret_password_clear_sync, "secret_password_clear_sync", LIBRARY_SECRET);
	Linker.link(secret_password_clearv, "secret_password_clearv", LIBRARY_SECRET);
	Linker.link(secret_password_clearv_sync, "secret_password_clearv_sync", LIBRARY_SECRET);
	Linker.link(secret_password_free, "secret_password_free", LIBRARY_SECRET);
	Linker.link(secret_password_lookup, "secret_password_lookup", LIBRARY_SECRET);
	Linker.link(secret_password_lookup_finish, "secret_password_lookup_finish", LIBRARY_SECRET);
	Linker.link(secret_password_lookup_nonpageable_finish, "secret_password_lookup_nonpageable_finish", LIBRARY_SECRET);
	Linker.link(secret_password_lookup_nonpageable_sync, "secret_password_lookup_nonpageable_sync", LIBRARY_SECRET);
	Linker.link(secret_password_lookup_sync, "secret_password_lookup_sync", LIBRARY_SECRET);
	Linker.link(secret_password_lookupv, "secret_password_lookupv", LIBRARY_SECRET);
	Linker.link(secret_password_lookupv_nonpageable_sync, "secret_password_lookupv_nonpageable_sync", LIBRARY_SECRET);
	Linker.link(secret_password_lookupv_sync, "secret_password_lookupv_sync", LIBRARY_SECRET);
	Linker.link(secret_password_store, "secret_password_store", LIBRARY_SECRET);
	Linker.link(secret_password_store_finish, "secret_password_store_finish", LIBRARY_SECRET);
	Linker.link(secret_password_store_sync, "secret_password_store_sync", LIBRARY_SECRET);
	Linker.link(secret_password_storev, "secret_password_storev", LIBRARY_SECRET);
	Linker.link(secret_password_storev_sync, "secret_password_storev_sync", LIBRARY_SECRET);
	Linker.link(secret_password_wipe, "secret_password_wipe", LIBRARY_SECRET);
}

__gshared extern(C)
{

	// secret.Collection

	GType function() c_secret_collection_get_type;
	SecretCollection* function(GAsyncResult* result, GError** err) c_secret_collection_new_for_dbus_path_finish;
	SecretCollection* function(SecretService* service, const(char)* collectionPath, SecretCollectionFlags flags, GCancellable* cancellable, GError** err) c_secret_collection_new_for_dbus_path_sync;
	void function(SecretService* service, const(char)* label, const(char)* alias_, SecretCollectionCreateFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_create;
	SecretCollection* function(GAsyncResult* result, GError** err) c_secret_collection_create_finish;
	SecretCollection* function(SecretService* service, const(char)* label, const(char)* alias_, SecretCollectionCreateFlags flags, GCancellable* cancellable, GError** err) c_secret_collection_create_sync;
	void function(SecretService* service, const(char)* alias_, SecretCollectionFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_for_alias;
	SecretCollection* function(GAsyncResult* result, GError** err) c_secret_collection_for_alias_finish;
	SecretCollection* function(SecretService* service, const(char)* alias_, SecretCollectionFlags flags, GCancellable* cancellable, GError** err) c_secret_collection_for_alias_sync;
	void function(SecretService* service, const(char)* collectionPath, SecretCollectionFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_new_for_dbus_path;
	void function(SecretCollection* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_delete;
	int function(SecretCollection* self, GAsyncResult* result, GError** err) c_secret_collection_delete_finish;
	int function(SecretCollection* self, GCancellable* cancellable, GError** err) c_secret_collection_delete_sync;
	ulong function(SecretCollection* self) c_secret_collection_get_created;
	SecretCollectionFlags function(SecretCollection* self) c_secret_collection_get_flags;
	GList* function(SecretCollection* self) c_secret_collection_get_items;
	char* function(SecretCollection* self) c_secret_collection_get_label;
	int function(SecretCollection* self) c_secret_collection_get_locked;
	ulong function(SecretCollection* self) c_secret_collection_get_modified;
	SecretService* function(SecretCollection* self) c_secret_collection_get_service;
	void function(SecretCollection* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_load_items;
	int function(SecretCollection* self, GAsyncResult* result, GError** err) c_secret_collection_load_items_finish;
	int function(SecretCollection* self, GCancellable* cancellable, GError** err) c_secret_collection_load_items_sync;
	void function(SecretCollection* self) c_secret_collection_refresh;
	void function(SecretCollection* self, SecretSchema* schema, GHashTable* attributes, SecretSearchFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_search;
	GList* function(SecretCollection* self, GAsyncResult* result, GError** err) c_secret_collection_search_finish;
	void function(SecretCollection* collection, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_search_for_dbus_paths;
	char** function(SecretCollection* collection, GAsyncResult* result, GError** err) c_secret_collection_search_for_dbus_paths_finish;
	char** function(SecretCollection* collection, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_collection_search_for_dbus_paths_sync;
	GList* function(SecretCollection* self, SecretSchema* schema, GHashTable* attributes, SecretSearchFlags flags, GCancellable* cancellable, GError** err) c_secret_collection_search_sync;
	void function(SecretCollection* self, const(char)* label, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_collection_set_label;
	int function(SecretCollection* self, GAsyncResult* result, GError** err) c_secret_collection_set_label_finish;
	int function(SecretCollection* self, const(char)* label, GCancellable* cancellable, GError** err) c_secret_collection_set_label_sync;

	// secret.Item

	GType function() c_secret_item_get_type;
	SecretItem* function(GAsyncResult* result, GError** err) c_secret_item_new_for_dbus_path_finish;
	SecretItem* function(SecretService* service, const(char)* itemPath, SecretItemFlags flags, GCancellable* cancellable, GError** err) c_secret_item_new_for_dbus_path_sync;
	void function(SecretCollection* collection, SecretSchema* schema, GHashTable* attributes, const(char)* label, SecretValue* value, SecretItemCreateFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_create;
	SecretItem* function(GAsyncResult* result, GError** err) c_secret_item_create_finish;
	SecretItem* function(SecretCollection* collection, SecretSchema* schema, GHashTable* attributes, const(char)* label, SecretValue* value, SecretItemCreateFlags flags, GCancellable* cancellable, GError** err) c_secret_item_create_sync;
	void function(GList* items, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_load_secrets;
	int function(GAsyncResult* result, GError** err) c_secret_item_load_secrets_finish;
	int function(GList* items, GCancellable* cancellable, GError** err) c_secret_item_load_secrets_sync;
	void function(SecretService* service, const(char)* itemPath, SecretItemFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_new_for_dbus_path;
	void function(SecretItem* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_delete;
	int function(SecretItem* self, GAsyncResult* result, GError** err) c_secret_item_delete_finish;
	int function(SecretItem* self, GCancellable* cancellable, GError** err) c_secret_item_delete_sync;
	GHashTable* function(SecretItem* self) c_secret_item_get_attributes;
	ulong function(SecretItem* self) c_secret_item_get_created;
	SecretItemFlags function(SecretItem* self) c_secret_item_get_flags;
	char* function(SecretItem* self) c_secret_item_get_label;
	int function(SecretItem* self) c_secret_item_get_locked;
	ulong function(SecretItem* self) c_secret_item_get_modified;
	char* function(SecretItem* self) c_secret_item_get_schema_name;
	SecretValue* function(SecretItem* self) c_secret_item_get_secret;
	SecretService* function(SecretItem* self) c_secret_item_get_service;
	void function(SecretItem* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_load_secret;
	int function(SecretItem* self, GAsyncResult* result, GError** err) c_secret_item_load_secret_finish;
	int function(SecretItem* self, GCancellable* cancellable, GError** err) c_secret_item_load_secret_sync;
	void function(SecretItem* self) c_secret_item_refresh;
	void function(SecretItem* self, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_set_attributes;
	int function(SecretItem* self, GAsyncResult* result, GError** err) c_secret_item_set_attributes_finish;
	int function(SecretItem* self, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_item_set_attributes_sync;
	void function(SecretItem* self, const(char)* label, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_set_label;
	int function(SecretItem* self, GAsyncResult* result, GError** err) c_secret_item_set_label_finish;
	int function(SecretItem* self, const(char)* label, GCancellable* cancellable, GError** err) c_secret_item_set_label_sync;
	void function(SecretItem* self, SecretValue* value, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_item_set_secret;
	int function(SecretItem* self, GAsyncResult* result, GError** err) c_secret_item_set_secret_finish;
	int function(SecretItem* self, SecretValue* value, GCancellable* cancellable, GError** err) c_secret_item_set_secret_sync;

	// secret.Prompt

	GType function() c_secret_prompt_get_type;
	void function(SecretPrompt* self, const(char)* windowId, GVariantType* returnType, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_prompt_perform;
	GVariant* function(SecretPrompt* self, GAsyncResult* result, GError** err) c_secret_prompt_perform_finish;
	GVariant* function(SecretPrompt* self, const(char)* windowId, GCancellable* cancellable, GVariantType* returnType, GError** err) c_secret_prompt_perform_sync;
	GVariant* function(SecretPrompt* self, const(char)* windowId, GCancellable* cancellable, GVariantType* returnType, GError** err) c_secret_prompt_run;

	// secret.Schema

	GType function() c_secret_schema_get_type;
	SecretSchema* function(const(char)* name, SecretSchemaFlags flags, ... ) c_secret_schema_new;
	SecretSchema* function(const(char)* name, SecretSchemaFlags flags, GHashTable* attributeNamesAndTypes) c_secret_schema_newv;
	SecretSchema* function(SecretSchema* schema) c_secret_schema_ref;
	void function(SecretSchema* schema) c_secret_schema_unref;

	// secret.SchemaAttribute

	GType function() c_secret_schema_attribute_get_type;

	// secret.Service

	GType function() c_secret_service_get_type;
	void function() c_secret_service_disconnect;
	void function(SecretServiceFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_get;
	SecretService* function(GAsyncResult* result, GError** err) c_secret_service_get_finish;
	SecretService* function(SecretServiceFlags flags, GCancellable* cancellable, GError** err) c_secret_service_get_sync;
	void function(GType serviceGtype, const(char)* serviceBusName, SecretServiceFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_open;
	SecretService* function(GAsyncResult* result, GError** err) c_secret_service_open_finish;
	SecretService* function(GType serviceGtype, const(char)* serviceBusName, SecretServiceFlags flags, GCancellable* cancellable, GError** err) c_secret_service_open_sync;
	void function(SecretService* service, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_clear;
	int function(SecretService* service, GAsyncResult* result, GError** err) c_secret_service_clear_finish;
	int function(SecretService* service, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_service_clear_sync;
	void function(SecretService* self, GHashTable* properties, const(char)* alias_, SecretCollectionCreateFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_create_collection_dbus_path;
	char* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_create_collection_dbus_path_finish;
	char* function(SecretService* self, GHashTable* properties, const(char)* alias_, SecretCollectionCreateFlags flags, GCancellable* cancellable, GError** err) c_secret_service_create_collection_dbus_path_sync;
	void function(SecretService* self, const(char)* collectionPath, GHashTable* properties, SecretValue* value, SecretItemCreateFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_create_item_dbus_path;
	char* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_create_item_dbus_path_finish;
	char* function(SecretService* self, const(char)* collectionPath, GHashTable* properties, SecretValue* value, SecretItemCreateFlags flags, GCancellable* cancellable, GError** err) c_secret_service_create_item_dbus_path_sync;
	SecretValue* function(SecretService* service, GVariant* value) c_secret_service_decode_dbus_secret;
	void function(SecretService* self, const(char)* itemPath, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_delete_item_dbus_path;
	int function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_delete_item_dbus_path_finish;
	int function(SecretService* self, const(char)* itemPath, GCancellable* cancellable, GError** err) c_secret_service_delete_item_dbus_path_sync;
	GVariant* function(SecretService* service, SecretValue* value) c_secret_service_encode_dbus_secret;
	void function(SecretService* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_ensure_session;
	int function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_ensure_session_finish;
	int function(SecretService* self, GCancellable* cancellable, GError** err) c_secret_service_ensure_session_sync;
	GType function(SecretService* self) c_secret_service_get_collection_gtype;
	GList* function(SecretService* self) c_secret_service_get_collections;
	SecretServiceFlags function(SecretService* self) c_secret_service_get_flags;
	GType function(SecretService* self) c_secret_service_get_item_gtype;
	void function(SecretService* self, const(char)* itemPath, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_get_secret_for_dbus_path;
	SecretValue* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_get_secret_for_dbus_path_finish;
	SecretValue* function(SecretService* self, const(char)* itemPath, GCancellable* cancellable, GError** err) c_secret_service_get_secret_for_dbus_path_sync;
	void function(SecretService* self, char** itemPaths, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_get_secrets_for_dbus_paths;
	GHashTable* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_get_secrets_for_dbus_paths_finish;
	GHashTable* function(SecretService* self, char** itemPaths, GCancellable* cancellable, GError** err) c_secret_service_get_secrets_for_dbus_paths_sync;
	const(char)* function(SecretService* self) c_secret_service_get_session_algorithms;
	const(char)* function(SecretService* self) c_secret_service_get_session_dbus_path;
	void function(SecretService* self, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_load_collections;
	int function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_load_collections_finish;
	int function(SecretService* self, GCancellable* cancellable, GError** err) c_secret_service_load_collections_sync;
	void function(SecretService* service, GList* objects, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_lock;
	void function(SecretService* self, char** paths, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_lock_dbus_paths;
	int function(SecretService* self, GAsyncResult* result, char*** locked, GError** err) c_secret_service_lock_dbus_paths_finish;
	int function(SecretService* self, char** paths, GCancellable* cancellable, char*** locked, GError** err) c_secret_service_lock_dbus_paths_sync;
	int function(SecretService* service, GAsyncResult* result, GList** locked, GError** err) c_secret_service_lock_finish;
	int function(SecretService* service, GList* objects, GCancellable* cancellable, GList** locked, GError** err) c_secret_service_lock_sync;
	void function(SecretService* service, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_lookup;
	SecretValue* function(SecretService* service, GAsyncResult* result, GError** err) c_secret_service_lookup_finish;
	SecretValue* function(SecretService* service, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_service_lookup_sync;
	void function(SecretService* self, SecretPrompt* prompt, GVariantType* returnType, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_prompt;
	void function(SecretService* self, const(char)* promptPath, GVariantType* returnType, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_prompt_at_dbus_path;
	GVariant* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_prompt_at_dbus_path_finish;
	GVariant* function(SecretService* self, const(char)* promptPath, GCancellable* cancellable, GVariantType* returnType, GError** err) c_secret_service_prompt_at_dbus_path_sync;
	GVariant* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_prompt_finish;
	GVariant* function(SecretService* self, SecretPrompt* prompt, GCancellable* cancellable, GVariantType* returnType, GError** err) c_secret_service_prompt_sync;
	void function(SecretService* self, const(char)* alias_, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_read_alias_dbus_path;
	char* function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_read_alias_dbus_path_finish;
	char* function(SecretService* self, const(char)* alias_, GCancellable* cancellable, GError** err) c_secret_service_read_alias_dbus_path_sync;
	void function(SecretService* service, SecretSchema* schema, GHashTable* attributes, SecretSearchFlags flags, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_search;
	GList* function(SecretService* service, GAsyncResult* result, GError** err) c_secret_service_search_finish;
	void function(SecretService* self, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_search_for_dbus_paths;
	int function(SecretService* self, GAsyncResult* result, char*** unlocked, char*** locked, GError** err) c_secret_service_search_for_dbus_paths_finish;
	int function(SecretService* self, SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, char*** unlocked, char*** locked, GError** err) c_secret_service_search_for_dbus_paths_sync;
	GList* function(SecretService* service, SecretSchema* schema, GHashTable* attributes, SecretSearchFlags flags, GCancellable* cancellable, GError** err) c_secret_service_search_sync;
	void function(SecretService* service, const(char)* alias_, SecretCollection* collection, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_set_alias;
	int function(SecretService* service, GAsyncResult* result, GError** err) c_secret_service_set_alias_finish;
	int function(SecretService* service, const(char)* alias_, SecretCollection* collection, GCancellable* cancellable, GError** err) c_secret_service_set_alias_sync;
	void function(SecretService* self, const(char)* alias_, const(char)* collectionPath, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_set_alias_to_dbus_path;
	int function(SecretService* self, GAsyncResult* result, GError** err) c_secret_service_set_alias_to_dbus_path_finish;
	int function(SecretService* self, const(char)* alias_, const(char)* collectionPath, GCancellable* cancellable, GError** err) c_secret_service_set_alias_to_dbus_path_sync;
	void function(SecretService* service, SecretSchema* schema, GHashTable* attributes, const(char)* collection, const(char)* label, SecretValue* value, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_store;
	int function(SecretService* service, GAsyncResult* result, GError** err) c_secret_service_store_finish;
	int function(SecretService* service, SecretSchema* schema, GHashTable* attributes, const(char)* collection, const(char)* label, SecretValue* value, GCancellable* cancellable, GError** err) c_secret_service_store_sync;
	void function(SecretService* service, GList* objects, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_unlock;
	void function(SecretService* self, char** paths, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_service_unlock_dbus_paths;
	int function(SecretService* self, GAsyncResult* result, char*** unlocked, GError** err) c_secret_service_unlock_dbus_paths_finish;
	int function(SecretService* self, char** paths, GCancellable* cancellable, char*** unlocked, GError** err) c_secret_service_unlock_dbus_paths_sync;
	int function(SecretService* service, GAsyncResult* result, GList** unlocked, GError** err) c_secret_service_unlock_finish;
	int function(SecretService* service, GList* objects, GCancellable* cancellable, GList** unlocked, GError** err) c_secret_service_unlock_sync;

	// secret.Value

	GType function() c_secret_value_get_type;
	SecretValue* function(const(char)* secret, ptrdiff_t length, const(char)* contentType) c_secret_value_new;
	SecretValue* function(char* secret, ptrdiff_t length, const(char)* contentType, GDestroyNotify destroy) c_secret_value_new_full;
	char* function(SecretValue* value, size_t* length) c_secret_value_get;
	const(char)* function(SecretValue* value) c_secret_value_get_content_type;
	const(char)* function(SecretValue* value) c_secret_value_get_text;
	SecretValue* function(SecretValue* value) c_secret_value_ref;
	void function(void* value) c_secret_value_unref;

	// secret.Secret

	void function(SecretSchema* schema, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData, ... ) c_secret_password_clear;
	int function(GAsyncResult* result, GError** err) c_secret_password_clear_finish;
	int function(SecretSchema* schema, GCancellable* cancellable, GError** error, ... ) c_secret_password_clear_sync;
	void function(SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_password_clearv;
	int function(SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_password_clearv_sync;
	void function(char* password) c_secret_password_free;
	void function(SecretSchema* schema, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData, ... ) c_secret_password_lookup;
	char* function(GAsyncResult* result, GError** err) c_secret_password_lookup_finish;
	char* function(GAsyncResult* result, GError** err) c_secret_password_lookup_nonpageable_finish;
	char* function(SecretSchema* schema, GCancellable* cancellable, GError** error, ... ) c_secret_password_lookup_nonpageable_sync;
	char* function(SecretSchema* schema, GCancellable* cancellable, GError** error, ... ) c_secret_password_lookup_sync;
	void function(SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_password_lookupv;
	char* function(SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_password_lookupv_nonpageable_sync;
	char* function(SecretSchema* schema, GHashTable* attributes, GCancellable* cancellable, GError** err) c_secret_password_lookupv_sync;
	void function(SecretSchema* schema, const(char)* collection, const(char)* label, const(char)* password, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData, ... ) c_secret_password_store;
	int function(GAsyncResult* result, GError** err) c_secret_password_store_finish;
	int function(SecretSchema* schema, const(char)* collection, const(char)* label, const(char)* password, GCancellable* cancellable, GError** error, ... ) c_secret_password_store_sync;
	void function(SecretSchema* schema, GHashTable* attributes, const(char)* collection, const(char)* label, const(char)* password, GCancellable* cancellable, GAsyncReadyCallback callback, void* userData) c_secret_password_storev;
	int function(SecretSchema* schema, GHashTable* attributes, const(char)* collection, const(char)* label, const(char)* password, GCancellable* cancellable, GError** err) c_secret_password_storev_sync;
	void function(char* password) c_secret_password_wipe;
}


// secret.Collection

alias c_secret_collection_get_type secret_collection_get_type;
alias c_secret_collection_new_for_dbus_path_finish secret_collection_new_for_dbus_path_finish;
alias c_secret_collection_new_for_dbus_path_sync secret_collection_new_for_dbus_path_sync;
alias c_secret_collection_create secret_collection_create;
alias c_secret_collection_create_finish secret_collection_create_finish;
alias c_secret_collection_create_sync secret_collection_create_sync;
alias c_secret_collection_for_alias secret_collection_for_alias;
alias c_secret_collection_for_alias_finish secret_collection_for_alias_finish;
alias c_secret_collection_for_alias_sync secret_collection_for_alias_sync;
alias c_secret_collection_new_for_dbus_path secret_collection_new_for_dbus_path;
alias c_secret_collection_delete secret_collection_delete;
alias c_secret_collection_delete_finish secret_collection_delete_finish;
alias c_secret_collection_delete_sync secret_collection_delete_sync;
alias c_secret_collection_get_created secret_collection_get_created;
alias c_secret_collection_get_flags secret_collection_get_flags;
alias c_secret_collection_get_items secret_collection_get_items;
alias c_secret_collection_get_label secret_collection_get_label;
alias c_secret_collection_get_locked secret_collection_get_locked;
alias c_secret_collection_get_modified secret_collection_get_modified;
alias c_secret_collection_get_service secret_collection_get_service;
alias c_secret_collection_load_items secret_collection_load_items;
alias c_secret_collection_load_items_finish secret_collection_load_items_finish;
alias c_secret_collection_load_items_sync secret_collection_load_items_sync;
alias c_secret_collection_refresh secret_collection_refresh;
alias c_secret_collection_search secret_collection_search;
alias c_secret_collection_search_finish secret_collection_search_finish;
alias c_secret_collection_search_for_dbus_paths secret_collection_search_for_dbus_paths;
alias c_secret_collection_search_for_dbus_paths_finish secret_collection_search_for_dbus_paths_finish;
alias c_secret_collection_search_for_dbus_paths_sync secret_collection_search_for_dbus_paths_sync;
alias c_secret_collection_search_sync secret_collection_search_sync;
alias c_secret_collection_set_label secret_collection_set_label;
alias c_secret_collection_set_label_finish secret_collection_set_label_finish;
alias c_secret_collection_set_label_sync secret_collection_set_label_sync;

// secret.Item

alias c_secret_item_get_type secret_item_get_type;
alias c_secret_item_new_for_dbus_path_finish secret_item_new_for_dbus_path_finish;
alias c_secret_item_new_for_dbus_path_sync secret_item_new_for_dbus_path_sync;
alias c_secret_item_create secret_item_create;
alias c_secret_item_create_finish secret_item_create_finish;
alias c_secret_item_create_sync secret_item_create_sync;
alias c_secret_item_load_secrets secret_item_load_secrets;
alias c_secret_item_load_secrets_finish secret_item_load_secrets_finish;
alias c_secret_item_load_secrets_sync secret_item_load_secrets_sync;
alias c_secret_item_new_for_dbus_path secret_item_new_for_dbus_path;
alias c_secret_item_delete secret_item_delete;
alias c_secret_item_delete_finish secret_item_delete_finish;
alias c_secret_item_delete_sync secret_item_delete_sync;
alias c_secret_item_get_attributes secret_item_get_attributes;
alias c_secret_item_get_created secret_item_get_created;
alias c_secret_item_get_flags secret_item_get_flags;
alias c_secret_item_get_label secret_item_get_label;
alias c_secret_item_get_locked secret_item_get_locked;
alias c_secret_item_get_modified secret_item_get_modified;
alias c_secret_item_get_schema_name secret_item_get_schema_name;
alias c_secret_item_get_secret secret_item_get_secret;
alias c_secret_item_get_service secret_item_get_service;
alias c_secret_item_load_secret secret_item_load_secret;
alias c_secret_item_load_secret_finish secret_item_load_secret_finish;
alias c_secret_item_load_secret_sync secret_item_load_secret_sync;
alias c_secret_item_refresh secret_item_refresh;
alias c_secret_item_set_attributes secret_item_set_attributes;
alias c_secret_item_set_attributes_finish secret_item_set_attributes_finish;
alias c_secret_item_set_attributes_sync secret_item_set_attributes_sync;
alias c_secret_item_set_label secret_item_set_label;
alias c_secret_item_set_label_finish secret_item_set_label_finish;
alias c_secret_item_set_label_sync secret_item_set_label_sync;
alias c_secret_item_set_secret secret_item_set_secret;
alias c_secret_item_set_secret_finish secret_item_set_secret_finish;
alias c_secret_item_set_secret_sync secret_item_set_secret_sync;

// secret.Prompt

alias c_secret_prompt_get_type secret_prompt_get_type;
alias c_secret_prompt_perform secret_prompt_perform;
alias c_secret_prompt_perform_finish secret_prompt_perform_finish;
alias c_secret_prompt_perform_sync secret_prompt_perform_sync;
alias c_secret_prompt_run secret_prompt_run;

// secret.Schema

alias c_secret_schema_get_type secret_schema_get_type;
alias c_secret_schema_new secret_schema_new;
alias c_secret_schema_newv secret_schema_newv;
alias c_secret_schema_ref secret_schema_ref;
alias c_secret_schema_unref secret_schema_unref;

// secret.SchemaAttribute

alias c_secret_schema_attribute_get_type secret_schema_attribute_get_type;

// secret.Service

alias c_secret_service_get_type secret_service_get_type;
alias c_secret_service_disconnect secret_service_disconnect;
alias c_secret_service_get secret_service_get;
alias c_secret_service_get_finish secret_service_get_finish;
alias c_secret_service_get_sync secret_service_get_sync;
alias c_secret_service_open secret_service_open;
alias c_secret_service_open_finish secret_service_open_finish;
alias c_secret_service_open_sync secret_service_open_sync;
alias c_secret_service_clear secret_service_clear;
alias c_secret_service_clear_finish secret_service_clear_finish;
alias c_secret_service_clear_sync secret_service_clear_sync;
alias c_secret_service_create_collection_dbus_path secret_service_create_collection_dbus_path;
alias c_secret_service_create_collection_dbus_path_finish secret_service_create_collection_dbus_path_finish;
alias c_secret_service_create_collection_dbus_path_sync secret_service_create_collection_dbus_path_sync;
alias c_secret_service_create_item_dbus_path secret_service_create_item_dbus_path;
alias c_secret_service_create_item_dbus_path_finish secret_service_create_item_dbus_path_finish;
alias c_secret_service_create_item_dbus_path_sync secret_service_create_item_dbus_path_sync;
alias c_secret_service_decode_dbus_secret secret_service_decode_dbus_secret;
alias c_secret_service_delete_item_dbus_path secret_service_delete_item_dbus_path;
alias c_secret_service_delete_item_dbus_path_finish secret_service_delete_item_dbus_path_finish;
alias c_secret_service_delete_item_dbus_path_sync secret_service_delete_item_dbus_path_sync;
alias c_secret_service_encode_dbus_secret secret_service_encode_dbus_secret;
alias c_secret_service_ensure_session secret_service_ensure_session;
alias c_secret_service_ensure_session_finish secret_service_ensure_session_finish;
alias c_secret_service_ensure_session_sync secret_service_ensure_session_sync;
alias c_secret_service_get_collection_gtype secret_service_get_collection_gtype;
alias c_secret_service_get_collections secret_service_get_collections;
alias c_secret_service_get_flags secret_service_get_flags;
alias c_secret_service_get_item_gtype secret_service_get_item_gtype;
alias c_secret_service_get_secret_for_dbus_path secret_service_get_secret_for_dbus_path;
alias c_secret_service_get_secret_for_dbus_path_finish secret_service_get_secret_for_dbus_path_finish;
alias c_secret_service_get_secret_for_dbus_path_sync secret_service_get_secret_for_dbus_path_sync;
alias c_secret_service_get_secrets_for_dbus_paths secret_service_get_secrets_for_dbus_paths;
alias c_secret_service_get_secrets_for_dbus_paths_finish secret_service_get_secrets_for_dbus_paths_finish;
alias c_secret_service_get_secrets_for_dbus_paths_sync secret_service_get_secrets_for_dbus_paths_sync;
alias c_secret_service_get_session_algorithms secret_service_get_session_algorithms;
alias c_secret_service_get_session_dbus_path secret_service_get_session_dbus_path;
alias c_secret_service_load_collections secret_service_load_collections;
alias c_secret_service_load_collections_finish secret_service_load_collections_finish;
alias c_secret_service_load_collections_sync secret_service_load_collections_sync;
alias c_secret_service_lock secret_service_lock;
alias c_secret_service_lock_dbus_paths secret_service_lock_dbus_paths;
alias c_secret_service_lock_dbus_paths_finish secret_service_lock_dbus_paths_finish;
alias c_secret_service_lock_dbus_paths_sync secret_service_lock_dbus_paths_sync;
alias c_secret_service_lock_finish secret_service_lock_finish;
alias c_secret_service_lock_sync secret_service_lock_sync;
alias c_secret_service_lookup secret_service_lookup;
alias c_secret_service_lookup_finish secret_service_lookup_finish;
alias c_secret_service_lookup_sync secret_service_lookup_sync;
alias c_secret_service_prompt secret_service_prompt;
alias c_secret_service_prompt_at_dbus_path secret_service_prompt_at_dbus_path;
alias c_secret_service_prompt_at_dbus_path_finish secret_service_prompt_at_dbus_path_finish;
alias c_secret_service_prompt_at_dbus_path_sync secret_service_prompt_at_dbus_path_sync;
alias c_secret_service_prompt_finish secret_service_prompt_finish;
alias c_secret_service_prompt_sync secret_service_prompt_sync;
alias c_secret_service_read_alias_dbus_path secret_service_read_alias_dbus_path;
alias c_secret_service_read_alias_dbus_path_finish secret_service_read_alias_dbus_path_finish;
alias c_secret_service_read_alias_dbus_path_sync secret_service_read_alias_dbus_path_sync;
alias c_secret_service_search secret_service_search;
alias c_secret_service_search_finish secret_service_search_finish;
alias c_secret_service_search_for_dbus_paths secret_service_search_for_dbus_paths;
alias c_secret_service_search_for_dbus_paths_finish secret_service_search_for_dbus_paths_finish;
alias c_secret_service_search_for_dbus_paths_sync secret_service_search_for_dbus_paths_sync;
alias c_secret_service_search_sync secret_service_search_sync;
alias c_secret_service_set_alias secret_service_set_alias;
alias c_secret_service_set_alias_finish secret_service_set_alias_finish;
alias c_secret_service_set_alias_sync secret_service_set_alias_sync;
alias c_secret_service_set_alias_to_dbus_path secret_service_set_alias_to_dbus_path;
alias c_secret_service_set_alias_to_dbus_path_finish secret_service_set_alias_to_dbus_path_finish;
alias c_secret_service_set_alias_to_dbus_path_sync secret_service_set_alias_to_dbus_path_sync;
alias c_secret_service_store secret_service_store;
alias c_secret_service_store_finish secret_service_store_finish;
alias c_secret_service_store_sync secret_service_store_sync;
alias c_secret_service_unlock secret_service_unlock;
alias c_secret_service_unlock_dbus_paths secret_service_unlock_dbus_paths;
alias c_secret_service_unlock_dbus_paths_finish secret_service_unlock_dbus_paths_finish;
alias c_secret_service_unlock_dbus_paths_sync secret_service_unlock_dbus_paths_sync;
alias c_secret_service_unlock_finish secret_service_unlock_finish;
alias c_secret_service_unlock_sync secret_service_unlock_sync;

// secret.Value

alias c_secret_value_get_type secret_value_get_type;
alias c_secret_value_new secret_value_new;
alias c_secret_value_new_full secret_value_new_full;
alias c_secret_value_get secret_value_get;
alias c_secret_value_get_content_type secret_value_get_content_type;
alias c_secret_value_get_text secret_value_get_text;
alias c_secret_value_ref secret_value_ref;
alias c_secret_value_unref secret_value_unref;

// secret.Secret

alias c_secret_password_clear secret_password_clear;
alias c_secret_password_clear_finish secret_password_clear_finish;
alias c_secret_password_clear_sync secret_password_clear_sync;
alias c_secret_password_clearv secret_password_clearv;
alias c_secret_password_clearv_sync secret_password_clearv_sync;
alias c_secret_password_free secret_password_free;
alias c_secret_password_lookup secret_password_lookup;
alias c_secret_password_lookup_finish secret_password_lookup_finish;
alias c_secret_password_lookup_nonpageable_finish secret_password_lookup_nonpageable_finish;
alias c_secret_password_lookup_nonpageable_sync secret_password_lookup_nonpageable_sync;
alias c_secret_password_lookup_sync secret_password_lookup_sync;
alias c_secret_password_lookupv secret_password_lookupv;
alias c_secret_password_lookupv_nonpageable_sync secret_password_lookupv_nonpageable_sync;
alias c_secret_password_lookupv_sync secret_password_lookupv_sync;
alias c_secret_password_store secret_password_store;
alias c_secret_password_store_finish secret_password_store_finish;
alias c_secret_password_store_sync secret_password_store_sync;
alias c_secret_password_storev secret_password_storev;
alias c_secret_password_storev_sync secret_password_storev_sync;
alias c_secret_password_wipe secret_password_wipe;
