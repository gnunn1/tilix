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


module secret.Secret;

private import gio.AsyncResultIF;
private import gio.Cancellable;
private import glib.ErrorG;
private import glib.GException;
private import glib.HashTable;
private import glib.Str;
private import secret.Schema;
private import secretc.secret;
public  import secretc.secrettypes;


/** */
public struct Secret
{

	/**
	 * Finish an asynchronous operation to remove passwords from the secret
	 * service.
	 *
	 * Params:
	 *     result = the asynchronous result passed to the callback
	 *
	 * Return: whether any passwords were removed
	 *
	 * Throws: GException on failure.
	 */
	public static bool passwordClearFinish(AsyncResultIF result)
	{
		GError* err = null;

		auto p = secret_password_clear_finish((result is null) ? null : result.getAsyncResultStruct(), &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Remove unlocked matching passwords from the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * All unlocked items that match the attributes will be deleted.
	 *
	 * This method will return immediately and complete asynchronously.
	 *
	 * Params:
	 *     schema = the schema for the attributes
	 *     attributes = the attribute keys and values
	 *     cancellable = optional cancellation object
	 *     callback = called when the operation completes
	 *     userData = data to be passed to the callback
	 */
	public static void passwordClearv(Schema schema, HashTable attributes, Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
	{
		secret_password_clearv((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), callback, userData);
	}

	/**
	 * Remove unlocked matching passwords from the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * All unlocked items that match the attributes will be deleted.
	 *
	 * This method may block indefinitely and should not be used in user interface
	 * threads.
	 *
	 * Params:
	 *     schema = the schema for the attributes
	 *     attributes = the attribute keys and values
	 *     cancellable = optional cancellation object
	 *
	 * Return: whether any passwords were removed
	 *
	 * Throws: GException on failure.
	 */
	public static bool passwordClearvSync(Schema schema, HashTable attributes, Cancellable cancellable)
	{
		GError* err = null;

		auto p = secret_password_clearv_sync((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Clear the memory used by a password, and then free it.
	 *
	 * This function must be used to free nonpageable memory returned by
	 * secret_password_lookup_nonpageable_finish(),
	 * secret_password_lookup_nonpageable_sync() or
	 * secret_password_lookupv_nonpageable_sync().
	 *
	 * Params:
	 *     password = password to free
	 */
	public static void passwordFree(string password)
	{
		secret_password_free(Str.toStringz(password));
	}

	/**
	 * Finish an asynchronous operation to lookup a password in the secret service.
	 *
	 * Params:
	 *     result = the asynchronous result passed to the callback
	 *
	 * Return: a new password string which should be freed with
	 *     secret_password_free() or may be freed with g_free() when done
	 *
	 * Throws: GException on failure.
	 */
	public static string passwordLookupFinish(AsyncResultIF result)
	{
		GError* err = null;

		auto retStr = secret_password_lookup_finish((result is null) ? null : result.getAsyncResultStruct(), &err);

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		scope(exit) Str.freeString(retStr);
		return Str.toString(retStr);
	}

	/**
	 * Finish an asynchronous operation to lookup a password in the secret service.
	 *
	 * Params:
	 *     result = the asynchronous result passed to the callback
	 *
	 * Return: a new password string stored in nonpageable memory
	 *     which must be freed with secret_password_free() when done
	 *
	 * Throws: GException on failure.
	 */
	public static string passwordLookupNonpageableFinish(AsyncResultIF result)
	{
		GError* err = null;

		auto retStr = secret_password_lookup_nonpageable_finish((result is null) ? null : result.getAsyncResultStruct(), &err);

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		scope(exit) Str.freeString(retStr);
		return Str.toString(retStr);
	}

	/**
	 * Lookup a password in the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * If no secret is found then %NULL is returned.
	 *
	 * This method will return immediately and complete asynchronously.
	 *
	 * Params:
	 *     schema = the schema for attributes
	 *     attributes = the attribute keys and values
	 *     cancellable = optional cancellation object
	 *     callback = called when the operation completes
	 *     userData = data to be passed to the callback
	 */
	public static void passwordLookupv(Schema schema, HashTable attributes, Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
	{
		secret_password_lookupv((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), callback, userData);
	}

	/**
	 * Lookup a password in the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * If no secret is found then %NULL is returned.
	 *
	 * This method may block indefinitely and should not be used in user interface
	 * threads.
	 *
	 * Params:
	 *     schema = the schema for attributes
	 *     attributes = the attribute keys and values
	 *     cancellable = optional cancellation object
	 *
	 * Return: a new password string stored in non pageable memory
	 *     which should be freed with secret_password_free() when done
	 *
	 * Throws: GException on failure.
	 */
	public static string passwordLookupvNonpageableSync(Schema schema, HashTable attributes, Cancellable cancellable)
	{
		GError* err = null;

		auto retStr = secret_password_lookupv_nonpageable_sync((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), &err);

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		scope(exit) Str.freeString(retStr);
		return Str.toString(retStr);
	}

	/**
	 * Lookup a password in the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * If no secret is found then %NULL is returned.
	 *
	 * This method may block indefinitely and should not be used in user interface
	 * threads.
	 *
	 * Params:
	 *     schema = the schema for attributes
	 *     attributes = the attribute keys and values
	 *     cancellable = optional cancellation object
	 *
	 * Return: a new password string which should be freed with
	 *     secret_password_free() or may be freed with g_free() when done
	 *
	 * Throws: GException on failure.
	 */
	public static string passwordLookupvSync(Schema schema, HashTable attributes, Cancellable cancellable)
	{
		GError* err = null;

		auto retStr = secret_password_lookupv_sync((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), (cancellable is null) ? null : cancellable.getCancellableStruct(), &err);

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		scope(exit) Str.freeString(retStr);
		return Str.toString(retStr);
	}

	/**
	 * Finish asynchronous operation to store a password in the secret service.
	 *
	 * Params:
	 *     result = the asynchronous result passed to the callback
	 *
	 * Return: whether the storage was successful or not
	 *
	 * Throws: GException on failure.
	 */
	public static bool passwordStoreFinish(AsyncResultIF result)
	{
		GError* err = null;

		auto p = secret_password_store_finish((result is null) ? null : result.getAsyncResultStruct(), &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Store a password in the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * If the attributes match a secret item already stored in the collection, then
	 * the item will be updated with these new values.
	 *
	 * If @collection is %NULL, then the default collection will be
	 * used. Use #SECRET_COLLECTION_SESSION to store the password in the session
	 * collection, which doesn't get stored across login sessions.
	 *
	 * This method will return immediately and complete asynchronously.
	 *
	 * Params:
	 *     schema = the schema for attributes
	 *     attributes = the attribute keys and values
	 *     collection = a collection alias, or D-Bus object path of the collection where to store the secret
	 *     label = label for the secret
	 *     password = the null-terminated password to store
	 *     cancellable = optional cancellation object
	 *     callback = called when the operation completes
	 *     userData = data to be passed to the callback
	 */
	public static void passwordStorev(Schema schema, HashTable attributes, string collection, string label, string password, Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
	{
		secret_password_storev((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), Str.toStringz(collection), Str.toStringz(label), Str.toStringz(password), (cancellable is null) ? null : cancellable.getCancellableStruct(), callback, userData);
	}

	/**
	 * Store a password in the secret service.
	 *
	 * The @attributes should be a set of key and value string pairs.
	 *
	 * If the attributes match a secret item already stored in the collection, then
	 * the item will be updated with these new values.
	 *
	 * If @collection is %NULL, then the default collection will be
	 * used. Use #SECRET_COLLECTION_SESSION to store the password in the session
	 * collection, which doesn't get stored across login sessions.
	 *
	 * This method may block indefinitely and should not be used in user interface
	 * threads.
	 *
	 * Params:
	 *     schema = the schema for attributes
	 *     attributes = the attribute keys and values
	 *     collection = a collection alias, or D-Bus object path of the collection where to store the secret
	 *     label = label for the secret
	 *     password = the null-terminated password to store
	 *     cancellable = optional cancellation object
	 *
	 * Return: whether the storage was successful or not
	 *
	 * Throws: GException on failure.
	 */
	public static bool passwordStorevSync(Schema schema, HashTable attributes, string collection, string label, string password, Cancellable cancellable)
	{
		GError* err = null;

		auto p = secret_password_storev_sync((schema is null) ? null : schema.getSchemaStruct(), (attributes is null) ? null : attributes.getHashTableStruct(), Str.toStringz(collection), Str.toStringz(label), Str.toStringz(password), (cancellable is null) ? null : cancellable.getCancellableStruct(), &err) != 0;

		if (err !is null)
		{
			throw new GException( new ErrorG(err) );
		}

		return p;
	}

	/**
	 * Clear the memory used by a password.
	 *
	 * Params:
	 *     password = password to clear
	 */
	public static void passwordWipe(string password)
	{
		secret_password_wipe(Str.toStringz(password));
	}
}
