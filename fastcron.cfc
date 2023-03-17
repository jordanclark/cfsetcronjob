component {
	// cfprocessingdirective( preserveCase=true );
	
	function init(
		required string apiKey
	,	string apiUrl= "https://www.fastcron.com/api/"
	,	numeric httpTimeOut= 120
	,	boolean debug
	) {
		arguments.debug = ( arguments.debug ?: request.debug ?: false );
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

		this.jobNotFound= {
			success= false
		,	error= "Job was not found"
		};

		return this;
	}

	function debugLog( required input ) {
		if( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if( isSimpleValue( arguments.input ) ) {
				request.log( "fastcronjob: " & arguments.input );
			} else {
				request.log( "fastcronjob: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			var info= ( isSimpleValue( arguments.input ) ? arguments.input : serializeJson( arguments.input ) );
			cftrace(
				var= "info"
			,	category= "fastcronjob"
			,	type= "information"
			);
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
		if( out.success ) {
			var item= "";
			for( item in out.response.data ) {
				arrayAppend( out.ip4, out.response.data[ item ].v4 );
				arrayAppend( out.ip6, out.response.data[ item ].v6 );
			}
		}
		return out;
	}

	////////////////////////////////////////////////////////////////////////////////////
	// CRON JOB METHODS
	// https://www.fastcron.com/documentation/api/cron
	////////////////////////////////////////////////////////////////////////////////////

	function jobAdd(
		required string name
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
	,	string httpHeaders
	,	string userAgent
	,	string username
	,	string password
	,	string postData= ""
	,	string notify= "NEVER"
	,	string notifyEvery= 1
	,	string failureThreshold= 10
	,	string pattern= ""
	,	string group= ""
	,	numeric retry= 3
	,	numeric retryAfter= 5
	,	boolean single= false
	,	boolean retryFailed= true
	) {
		if( structKeyExists( arguments, "notify" ) && !isNumeric( arguments.notify ) ) {
			arguments.notify= this.notifyLookup[ arguments.notify ];
		}
		if( isNumeric( arguments.group ) ) {
			arguments.group= arguments.group;
		} else {
			arguments.group= this.groupLookup( arguments.group );
		}
		var out= this.apiRequest( api= "cron.add", argumentCollection= arguments );
		// cache new job 
		if( out.success ) {
			this.jobCache[ out.response.data.id ]= out.response.data.id;
			if( len( out.response.data.name ) ) {
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
	,	string retry= ""
	,	string retryAfter= ""
	,	string single= ""
	,	string retryFailed= ""
	) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.name= arguments.idOrName;
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			return this.jobNotFound;
		}
		structDelete( arguments, "idOrName" );
		if( structKeyExists( arguments, "notify" ) && !isNumeric( arguments.notify ) ) {
			arguments.notify= this.notifyLookup[ arguments.notify ];
		}
		if( structKeyExists( arguments, "group" ) && isNumeric( arguments.group ) ) {
			arguments.group= arguments.group;
		} else {
			arguments.group= this.groupLookup( arguments.group );
		}
		var out= this.apiRequest( api= "cron.edit", argumentCollection= arguments );
		// cache name job 
		if( out.success ) {
			this.jobCache[ out.response.data.id ]= out.response.data.id;
			if( len( out.response.data.name ) ) {
				this.jobCache[ out.response.data.name ]= out.response.data.id;
			}
		}
		return out;
	}

	function jobUpsert(
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
	,	string retry= ""
	,	string retryAfter= ""
	,	string single= ""
	,	string retryFailed= ""
	) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.name= arguments.idOrName;
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			arguments.name= arguments.idOrName;
		}
		structDelete( arguments, "idOrName" );
		if( structKeyExists( arguments, "notify" ) && !isNumeric( arguments.notify ) ) {
			arguments.notify= this.notifyLookup[ arguments.notify ];
		}
		if( structKeyExists( arguments, "group" ) && isNumeric( arguments.group ) ) {
			arguments.group= arguments.group;
		} else {
			arguments.group= this.groupLookup( arguments.group );
		}
		var out;
		if( arguments.id < 0 ) {
			structDelete( arguments, "id" );
			out= this.apiRequest( api= "cron.add", argumentCollection= arguments );
		}
		else {
			out= this.apiRequest( api= "cron.edit", argumentCollection= arguments );
		}
		// cache name job 
		if( out.success ) {
			this.jobCache[ out.response.data.id ]= out.response.data.id;
			if( len( out.response.data.name ) ) {
				this.jobCache[ out.response.data.name ]= out.response.data.id;
			}
		}
		return out;
	}

	function jobGet( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.get", id= arguments.id );
			out.job= {};
			if( out.success ) {
				out.job= out.response.data;
			}
		}
		return out;
	}

	function jobEnable( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.enable", id= arguments.id )
		}
		return out;
	}

	function jobDisable( required string idOrName, required string length ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.pause", id= arguments.id, for= arguments.length )
		}
		return out;
	}

	function jobPause( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.disable", id= arguments.id )
		}
		return out;
	}

	array function jobToggleMatches( required boolean enable, required string matches ) {
		var job= 0;
		var update= 0;
		var batch= [];
		var jobs= this.jobList();
		arrayAppend( batch, jobs );
		for( job in jobs.response.data ) {
			if( listFindNoCase( arguments.matches, job.id ) || reFindNoCase( arguments.matches, job.name ) ) {
				if( arguments.enable ) {
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
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.delete", id= arguments.id );
			// un-cache job 
			if( out.success ) {
				structDelete( this.jobLookup, arguments.id );
				structDelete( this.jobLookup, arguments.idOrName );
			}
		}		
		return out;
	}

	function jobRun( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.run", id= arguments.id );
		}
		return out;
	}

	function jobLogs( required string idOrName, numeric limit= 250 ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.logs", id= arguments.id, limit= arguments.limit );
		}
		return out;
	}

	function jobFailures( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.jobLookup( arguments.idOrName );
		}
		if( arguments.id < 0 ) {
			var out= this.jobNotFound;
		} else {
			var out= this.apiRequest( api= "cron.failures", id= arguments.id );
		}
		return out;
	}

	function jobList( string keyword= "" ) {
		return this.apiRequest( api= "cron.list", keyword= arguments.keyword );
	}

	function jobLookup( required string name, boolean reload= false ) {
		if( arguments.reload ) {
			structDelete( this.jobCache, arguments.name );
		}
		if( !structKeyExists( this.jobCache, arguments.name ) ) {	
			var out= this.jobList( arguments.name );
			if( out.success ) {
				for( var job in out.response.data ) {
					this.jobCache[ job.id ]= job.id;
					if( len( job.name ) ) {
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
	// https://www.fastcron.com/documentation/api/group
	////////////////////////////////////////////////////////////////////////////////////

	function groupList() {
		return this.apiRequest( api= "group.list" );
	}

	function groupGet( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
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
		if( out.success ) {
			this.groupCache[ out.response.data.id ]= out.response.data.id;
			this.groupCache[ out.response.data.name ]= out.response.data.id;
		}
		return out;
	}

	function groupEdit( required string idOrName, required string name ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.edit", id= arguments.id, name= arguments.name );
		// cache group 
		if( out.success ) {
			this.groupCache[ out.response.data.id ]= out.response.data.id;
			this.groupCache[ out.response.data.name ]= out.response.data.id;
		}
		return out;
	}

	function groupDelete( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.delete", id= arguments.id );
		// un-cache job 
		if( out.success ) {
			structDelete( this.groupLookup, arguments.id );
			structDelete( this.groupLookup, arguments.idOrName );
		}
		return out;
	}

	function groupVanish( required string idOrName ) {
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		var out= this.apiRequest( api= "group.vanish", id= arguments.id );
		// un-cache job 
		if( out.success ) {
			structDelete( this.groupLookup, arguments.id );
			structDelete( this.groupLookup, arguments.idOrName );
		}
		return out;
	}

	function groupEmpty( required string idOrName ) {
		var out= "";
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "group.empty", id= arguments.id );
	}

	function groupItems( required string idOrName ) {
		var out= "";
		if( isNumeric( arguments.idOrName ) ) {
			arguments.id= arguments.idOrName;
		} else {
			arguments.id= this.groupLookup( arguments.idOrName );
		}
		return this.apiRequest( api= "group.items", id= arguments.id );
	}

	function groupLookup( required string name, boolean reload= false ) {
		if( structIsEmpty( this.groupCache ) || arguments.reload ) {
			var out= this.groupList();
			if( out.success ) {
				var group= "";
				this.groupCache= {};
				for( group in out.response.data ) {
					this.groupCache[ group.id ]= group.id;
					if( len( group.name ) ) {
						this.groupCache[ group.name ]= group.id;
					}
				}
			}
		}
		return ( structKeyExists( this.groupCache, arguments.name ) ? this.groupCache[ arguments.name ] : "" );
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
		cftimer( type="debug", label="fastcronjob request" ) {
			cfhttp( result="http", method="GET", url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut );
		}
		// this.debugLog( http );
		out.response= toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode = http.responseHeader.Status_Code ?: 500;
		if( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		// parse response 
		if( len( out.response ) ) {
			try {
				out.response= deserializeJSON( out.response );
				if( isStruct( out.response ) && structKeyExists( out.response, "status" ) && out.response.status == "error" ) {
					out.success= false;
					out.error= out.response.message;
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & (cfcatch.message?:"No catch message") & " " & (cfcatch.detail?:"No catch detail");
			}
		}
		if( len( out.error ) ) {
			out.success= false;
		}
		this.debugLog( out.statusCode & " " & out.error );
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode= true ) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= "?";
		for( sItem in arguments.stInput ) {
			if( !isNull( arguments.stInput[ sItem ] ) && len( arguments.stInput[ sItem ] ) ) {
				sValue= arguments.stInput[ sItem ];
				if( arguments.bEncode ) {
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