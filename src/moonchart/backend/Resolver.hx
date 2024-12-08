package moonchart.backend;

import haxe.ds.ObjectMap;

class DataResolver<F:{}, D, T> extends BasicResolver<F, D->T>
{
	public function resolveDataToBasic(?ID:F, ?data:D):T
	{
		if (!existsToBasic(ID) || ID == null || data == null)
			return defToBasicResolve(data);

		return toBasic.get(ID)(data);
	}
}

class IDResolver<F:{}, T:{}> extends BasicResolver<F, T>
{
	var fromBasic:ObjectMap<T, F>;
	var defFromBasicResolve:F;

	public function new(defToBasicResolve:T, defFromBasicResolve:F)
	{
		super(defToBasicResolve);
		fromBasic = new ObjectMap<T, F>();
		this.defFromBasicResolve = defFromBasicResolve;
	}

	public override function register(from:F, to:T):Void
	{
		super.register(from, to);
		registerFromBasic(to, from);
	}

	public function registerFromBasic(ID:T, resolver:F):Void
	{
		fromBasic.set(ID, resolver);
	}

	public function resolveFromBasic(?ID:T):F
	{
		if (!existsFromBasic(ID) || ID == null)
			return defFromBasicResolve;

		return fromBasic.get(ID);
	}

	public function existsFromBasic(ID:T):Bool
	{
		return fromBasic.exists(ID);
	}
}

@:private
@:noCompletion
class BasicResolver<F:{}, T>
{
	var toBasic:ObjectMap<F, T>;
	var defToBasicResolve:T;

	public function new(defToBasicResolve:T)
	{
		toBasic = new ObjectMap<F, T>();
		this.defToBasicResolve = defToBasicResolve;
	}

	public function register(from:F, to:T):Void
	{
		registerToBasic(from, to);
	}

	public function registerToBasic(ID:F, resolver:T):Void
	{
		toBasic.set(ID, resolver);
	}

	public function resolveToBasic(?ID:F):T
	{
		if (!existsToBasic(ID) || ID == null)
			return defToBasicResolve;

		return toBasic.get(ID);
	}

	public function existsToBasic(ID:F):Bool
	{
		return toBasic.exists(ID);
	}
}
