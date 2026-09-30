class KILL_VOTING_CONFIG {
	static _DEFAULT = 2;
	static _DEFAULT_SPECIFIC = {
		ot3_necropolis_ffa: 1,
	};
	static get DEFAULT() {
		return this._DEFAULT_SPECIFIC[MAP_NAME] || this._DEFAULT;
	}
	static TOKEN_COSTS = 1;
	static _INCREASE_BY_TOKEN = {
		ot3_necropolis_ffa: 10,
	};
	static _INCREASE_BY_TOKEN_DEFAULT = 2;
	static get TOKEN_KL() {
		return this._INCREASE_BY_TOKEN[MAP_NAME] || this._INCREASE_BY_TOKEN_DEFAULT;
	}
	static TYPE_DEFAULT = "Default";
	static TYPE_TOKEN = "Token";
	static VOTE_TYPE = {
		DEFAULT: 1,
		TOKEN: 2,
	};
}

class DOUBLE_MMR_TOKEN_CONFIG {
	static TOKEN_COSTS = 1;
}
