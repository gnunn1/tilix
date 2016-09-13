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


module secret.Value;

private import glib.ConstructionException;
private import glib.Str;
private import gobject.ObjectG;
private import secretc.secret;
public  import secretc.secrettypes;


/**
 * A secret value, like a password or other binary secret.
 */
public class Value
{
	/** the main Gtk struct */
	protected SecretValue* secretValue;
	protected bool ownedRef;

	/** Get the main Gtk struct */
	public SecretValue* getValueStruct()
	{
		return secretValue;
	}

	/** the main Gtk struct as a void* */
	protected void* getStruct()
	{
		return cast(void*)secretValue;
	}

	/**
	 * Sets our main struct and passes it to the parent class.
	 */
	public this (SecretValue* secretValue, bool ownedRef = false)
	{
		this.secretValue = secretValue;
		this.ownedRef = ownedRef;
	}


	/** */
	public static GType getType()
	{
		return secret_value_get_type();
	}

	/**
	 * Create a #SecretValue for the secret data passed in. The secret data is
	 * copied into non-pageable 'secure' memory.
	 *
	 * If the length is less than zero, then @secret is assumed to be
	 * null-terminated.
	 *
	 * Params:
	 *     secret = the secret data
	 *     length = the length of the data
	 *     contentType = the content type of the data
	 *
	 * Return: the new #SecretValue
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
	public this(string secret, ptrdiff_t length, string contentType)
	{
		auto p = secret_value_new(Str.toStringz(secret), length, Str.toStringz(contentType));

		if(p is null)
		{
			throw new ConstructionException("null returned by new");
		}

		this(cast(SecretValue*) p);
	}

	/**
	 * Create a #SecretValue for the secret data passed in. The secret data is
	 * not copied, and will later be freed with the @destroy function.
	 *
	 * If the length is less than zero, then @secret is assumed to be
	 * null-terminated.
	 *
	 * Params:
	 *     secret = the secret data
	 *     length = the length of the data
	 *     contentType = the content type of the data
	 *     destroy = function to call to free the secret data
	 *
	 * Return: the new #SecretValue
	 *
	 * Throws: ConstructionException GTK+ fails to create the object.
	 */
	public this(string secret, ptrdiff_t length, string contentType, GDestroyNotify destroy)
	{
		auto p = secret_value_new_full(Str.toStringz(secret), length, Str.toStringz(contentType), destroy);

		if(p is null)
		{
			throw new ConstructionException("null returned by new_full");
		}

		this(cast(SecretValue*) p);
	}

	/**
	 * Get the secret data in the #SecretValue. The value is not necessarily
	 * null-terminated unless it was created with secret_value_new() or a
	 * null-terminated string was passed to secret_value_new_full().
	 *
	 * Return: the secret data
	 */
	public string get()
	{
		size_t length;

		return Str.toString(secret_value_get(secretValue, &length));
	}

	/**
	 * Get the content type of the secret value, such as
	 * <literal>text/plain</literal>.
	 *
	 * Return: the content type
	 */
	public string getContentType()
	{
		return Str.toString(secret_value_get_content_type(secretValue));
	}

	/**
	 * Get the secret data in the #SecretValue if it contains a textual
	 * value. The content type must be <literal>text/plain</literal>.
	 *
	 * Return: the content type
	 */
	public string getText()
	{
		return Str.toString(secret_value_get_text(secretValue));
	}

	/**
	 * Add another reference to the #SecretValue. For each reference
	 * secret_value_unref() should be called to unreference the value.
	 *
	 * Return: the value
	 */
	public Value doref()
	{
		auto p = secret_value_ref(secretValue);

		if(p is null)
		{
			return null;
		}

		return ObjectG.getDObject!(Value)(cast(SecretValue*) p, true);
	}

	/**
	 * Unreference a #SecretValue. When the last reference is gone, then
	 * the value will be freed.
	 */
	public void unref()
	{
		secret_value_unref(secretValue);
	}
}
