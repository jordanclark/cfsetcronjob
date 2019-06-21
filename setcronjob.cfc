component {

	function init(
		required string apiKey
	,	string apiUrl= "https://www.setcronjob.com/api/"
	,	numeric httpTimeOut= 120
	,	boolean debug= ( request.debug ?: false )
	) {
		this.apiKey= arguments.apiKey;
		this.apiUrl= arguments.apiUrl;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug= arguments.debug;
		// 0= ACTIVE= Cronjob is active and running 
		// 1= DISABLED= Disabled by user 
		// 2= EXPIRED= Disabled due to account expired 
		// 3= INACTIVE= Disabled due to not enough account points 
		// 4= FAILED= Disabled due to many consecutive failures 
		this.statusCodes= {
			"0"= "ACTIVE"
		,	"1"= "DISABLED"
		,	"2"= "EXPIRED"
		,	"3"= "INACTIVE"
		,	"4"= "FAILED"
		};
		this.statusLookup= {
			"ACTIVE"= 0
		,	"DISABLED"= 1
		,	"EXPIRED"= 2
		,	"INACTIVE"= 3
		,	"FAILED"= 4
		};
		// 0= NEVER= Never send you any notification 
		// 1= FAILURE= Notify you when cronjob fails 
		// 2= ALWAYS= Notify you when cronjob is executed 
		// 3= DISABLED= Notify you only when cronjob disabled because of multiple consecutive failures 
		this.notifyCodes= {
			"0"= "NEVER"
		,	"1"= "FAILURE"
		,	"2"= "ALWAYS"
		,	"3"= "DISABLED"
		};
		this.notifyLookup= {
			"NEVER"= 0
		,	"FAILURE"= 1
		,	"ALWAYS"= 2
		,	"DISABLED"= 3
		};
		this.jobCache= {};
		this.groupCache= {};
		// alternate names for methods 
		this.cronAdd= this.jobAdd;
		this.cronEdit= this.jobEdit;
		this.cronGet= this.jobGet;
		this.cronEnable= this.jobEnable;
		this.cronDisable= this.jobDisable;
		this.cronToggleMatches= this.jobToggleMatches;
		this.cronDelete= this.jobDelete;
		this.cronRun= this.jobRun;
		this.cronLogs= this.jobLogs;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "setcronjob: " & arguments.input );
			} else {
				request.log( "setcronjob: (complex type)" );
				request.log( arguments.input );
			}
		} else if ( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="setcronjob", type="information" );
		}
		return;
	}

	function time() {
		return this.apiRequest( api= "server.time" );
	}

	function useragent() {
		return this.apiRequest( api= "server.useragent" );
	}

	function ipList() {
		var out= this.apiRequest( api= "server.ip" );
		out.ip4= [];
		out.ip6= [];
		if ( out.success ) {
			var item= "";
			for ( item in out.response.data ) {
				arrayAppend( out.ip4, out.response.data[ item ].v4 );
				arrayAppend( out.ip6, out.response.data[ item ].v6 );
			}
		}
		return out;
	}

	////////////////////////////////////////////////////////////////////////////////////
	// CRON JOB METHODS
	// https://www.setcronjob.com/documentation/api/cron
	////////////////////////////////////////////////////////////////////////////////////

	function jobAdd(
		required string idOrName
	,	required string url
	,	second
	,	minute
	,	hour
	,	day
	,	month
	,	weekday
	,	string expression= ""
	,	string timezone
	,	string httpMethod= "GET"
	,	string postData= ""
	,	string notify= "NEVER"
	,	string notifyEvery= 1
	,	string failureThreshold= 10
	,	string pattern= ""
	,	string group= 0
	,	string name= ""
	) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		structDelete( arguments, "idOrName" );
		if ( structKeyExists( arguments, "notify" ) && !isNumeric( arguments.notify ) ) {
			arguments.notify= this.notifyLookup[ arguments.notify ];
		}
		if ( isNumeric( arguments.group ) ) {
			arguments.groupID= arguments.group;
		} else {
			arguments.groupID= this.groupLookup( arguments.group );
		}
		structDelete( arguments, "group" );
		var out= this.apiRequest( api= "cron.edit", argumentCollection= arguments );
		// cache new job 
		if ( out.success ) {
			this.jobCache[ out.response.data.id ]= out.response.data.id;
			if ( len( out.response.data.name ) ) {
				this.jobCache[ out.response.data.name ]= out.response.data.id;
			}
		}
		return out;
	}

	function jobEdit(
		required string idOrName
	,	required string url
	,	second
	,	minute
	,	hour
	,	day
	,	month
	,	weekday
	,	string expression
	,	string timezone
	,	string httpMethod
	,	string postData
	,	string notify
	,	string notifyEvery
	,	string failureThreshold
	,	string pattern
	,	string group
	,	string name
	) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		structDelete( arguments, "idOrName" );
		if ( structKeyExists( arguments, "notify" ) && !isNumeric( arguments.notify ) ) {
			arguments.notify= this.notifyLookup[ arguments.notify ];
		}
		if ( structKeyExists( arguments, "group" ) && isNumeric( arguments.group ) ) {
			arguments.groupID= arguments.group;
		} else {
			arguments.groupID= this.groupLookup( arguments.group );
		}
		structDelete( arguments, "group" );
		var out= this.apiRequest( api= "cron.edit", argumentCollection= arguments );
		// cache name job 
		if ( out.success ) {
			this.jobCache[ out.response.data.id ]= out.response.data.id;
			if ( len( out.response.data.name ) ) {
				this.jobCache[ out.response.data.name ]= out.response.data.id;
			}
		}
		return out;
	}

	function jobGet( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "cron.get", id= arguments.id );
		out.job= {};
		if ( out.success ) {
			out.job= out.response.data;
		}
		return out;
	}

	function jobEnable( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "cron.enable", id= arguments.id );
	}

	function jobDisable( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "cron.disable", id= arguments.id );
	}

	array function jobToggleMatches( required boolean enable, required string matches ) {
		var job= 0;
		var update= 0;
		var batch= [];
		var jobs= this.jobList();
		arrayAppend( batch, jobs );
		for ( job in jobs.response.data ) {
			if ( listFindNoCase( arguments.matches, job.id ) || reFindNoCase( arguments.matches, job.name ) ) {
				if ( arguments.enable ) {
					update= this.jobEnable( job.id );
				} else {
					update= this.jobDisable( job.id );
				}
				arrayAppend( batch, update );
			}
		}
		return batch;
	}

	function jobDelete( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "cron.delete", id= arguments.id );
		// un-cache job 
		if ( out.success ) {
			structDelete( this.jobLookup, arguments.id );
			structDelete( this.jobLookup, arguments.idOrName );
		}
		return out;
	}

	function jobRun( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "cron.run", id= arguments.id );
	}

	function jobLogs( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "cron.logs", id= arguments.id );
	}

	function jobList() {
		return this.apiRequest( api= "cron.list" );
	}

	function jobLookup( required string name, boolean reload= false ) {
		if ( structIsEmpty( this.jobCache ) || arguments.reload ) {
			var out= this.jobList();
			if ( out.success ) {
				var job= 0;
				this.jobCache= {};
				for ( job in out.response.data ) {
					this.jobCache[ job.id ]= job.id;
					if ( len( job.name ) ) {
						this.jobCache[ job.name ]= job.id;
					}
				}
			} else {
				this.debugLog( "Failed to load joblist()" );
				this.debugLog( out );
			}
		}
		return ( structKeyExists( this.jobCache, arguments.name ) ? this.jobCache[ arguments.name ] : -1 );
	}

	////////////////////////////////////////////////////////////////////////////////////
	// GROUP METHODS
	// https://www.setcronjob.com/documentation/api/group
	////////////////////////////////////////////////////////////////////////////////////

	function groupList() {
		return this.apiRequest( api= "group.list" );
	}

	function groupGet( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "group.get", id= arguments.id );
	}

	function groupAdd( required string name ) {
		var out= this.apiRequest(
			api= "group.add"
		,	name= arguments.name
		);
		// cache new group 
		if ( out.success ) {
			this.groupCache[ out.response.data.id ]= out.response.data.id;
			this.groupCache[ out.response.data.name ]= out.response.data.id;
		}
		return out;
	}

	function groupEdit( required string idOrName, required string name ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.edit", id= arguments.id, name= arguments.name );
		// cache group 
		if ( out.success ) {
			this.groupCache[ out.response.data.id ]= out.response.data.id;
			this.groupCache[ out.response.data.name ]= out.response.data.id;
		}
		return out;
	}

	function groupDelete( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.delete", id= arguments.id );
		// un-cache job 
		if ( out.success ) {
			structDelete( this.groupLookup, arguments.id );
			structDelete( this.groupLookup, arguments.idOrName );
		}
		return out;
	}

	function groupVanish( required string idOrName ) {
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.vanish", id= arguments.id );
		// un-cache job 
		if ( out.success ) {
			structDelete( this.groupLookup, arguments.id );
			structDelete( this.groupLookup, arguments.idOrName );
		}
		return out;
	}

	function groupEmpty( required string idOrName ) {
		var out= "";
		if ( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "group.vanish", id= arguments.id );
	}

	function groupLookup( required string name, boolean reload= false ) {
		if ( structIsEmpty( this.groupCache ) || arguments.reload ) {
			var out= this.groupList();
			if ( out.success ) {
				var group= 0;
				this.groupCache= {};
				for ( group in out.response.data ) {
					this.groupCache[ group.id ]= group.id;
					if ( len( group.name ) ) {
						this.groupCache[ group.name ]= group.id;
					}
				}
			}
		}
		return ( structKeyExists( this.groupCache, arguments.name ) ? this.groupCache[ arguments.name ] : 0 );
	}

	struct function apiRequest( required string api ) {
		var http= 0;
		var dataKeys= 0;
		var item= "";
		var out= {
			success= false
		,	error= ""
		,	status= ""
		,	statusCode= 0
		,	response= ""
		,	requestUrl= this.apiUrl & arguments.api
		};
		structDelete( arguments, "api" );
		arguments.token= this.apiKey;
		out.requestUrl &= this.structToQueryString( arguments );
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		cftimer( type="debug", label="setcronjob request" ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut );
		}
		// this.debugLog( http );
		out.response= toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		if ( len( out.response ) ) {
			try {
				out.response= deserializeJSON( out.response );
				if ( isStruct( out.response ) && structKeyExists( out.response, "status" ) && out.response.status == "error" ) {
					out.success= false;
					out.error= out.response.message;
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode= true ) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= "?";
		for ( sItem in stInput ) {
			if ( !isNull( stInput[ sItem ] ) ) {
				sValue= stInput[ sItem ];
				if ( bEncode ) {
					sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue );
				} else {
					sOutput &= amp & lCase( sItem ) & "=" & sValue;
				}
				amp= "&";
			}
		}
		return sOutput;
	}

}