Include Audience

/// custom.rg.Pick
/// See <code>custom.rg.GetPicsRule</code> for related code.
/// 
/// @docs https://github.com/registerguard/pick
/// @copyright Copyright (c) 2013 Micky Hulse/The Register-Guard.
/// @license Released under the Apache License, Version 2.0.
/// http://www.apache.org/licenses/LICENSE-2.0
/// @version 1.0.0
/// @date Monday, January 7, 2013
Class custom.rg.Pick Extends %RegisteredObject
{

/// @param story { dt.cms.schema.CMSStory } CMSStory object to pull the pictures from (required).
/// @param position { %String } Picture item position (required).
/// @param items { %String } Number of CMSPicture objects to return; the default number is '5'.
/// @param include { %String } Include only these priorities (comma delimited list).
/// @param exclude { %String } Exclude only these priorities (comma delimited list).
/// @param order { %String } Custom ORDER BY, used in SQL statement.
ClassMethod pics(
	story As dt.cms.schema.CMSStory = -1,
	position As %String = "",
	items As %Integer = 5,
	include As %String = "",
	exclude As %String = "",
	order As %String = "") As %ListOfObjects
{
		
		; Need these features:
		; 1. Get an individual picture based on a single priority of X (inclusive).
		; 2. Get all pictures with a priority of X (exclusive).
		; 3. Limit the number of items returned.
		; 4. Custom SQL ordering.
		
		; @TODO:
		; Make private method to return %ResultSet or %String for query.
		; Another method to return the count.
		; A final method to return %ListOfObjects.
		; Accept priorityName and have it resolve to priorityId?
		; We could also ORDER BY fhdr.priorityid and have that trump fdbl.vieworder.
		; Accept ID or Story Obj for story attribute (do an $isobject or $validnum check).
		
		/*--------------------------------------------------------------------*/
		
		/**
		 * Trims white space and builds a list.
		 *
		 * set items = "foo, bar, baz"
		 * $$$lister(items) // "items" is now a list.
		 *
		 * @todo Force %list argument into a string before processing? Example: set %list = %list _ ""
		 *
		 * @see https://groups.google.com/d/topic/intersystems-public-cache/8iJV1p3kwD8/discussion
		 * @see https://gist.github.com/4008569
		 *
		 * @param %list { string } Comma delimited list; this argument must be passed as a variable (not a string).
		 * @return { $list } The %list parameter as a $list.
		 */
		
		#define lister(%list)                                                                   ##Continue
			set temp = ""                                                                       ##Continue
			for ##Unique(new)=1:1:$length(%list, ",") {                                         ##Continue
				set temp = temp _ $listbuild($zstrip($piece(%list, ",", ##Unique(old)), "<>W")) ##Continue
			}                                                                                   ##Continue
			set %list = temp                                                                    ##Continue
			kill temp
		
		/*----------------------------------*/
		
		/**
		 * Creates an array of key => values.
		 *
		 * $$$pbuild("areaID")
		 * $$$pbuild("sectionId")
		 * w params(1)
		 * // someMethod(params...)
		 *
		 * @see http://docs.intersystems.com/cache20091/csp/docbook/DocBook.UI.Page.cls?KEY=GOBJ_methods#GOBJ_methods_args_variable
		 * @see https://groups.google.com/d/topic/dti-lightning/5avEj-4twNE/discussion
		 *
		 * @param %v { mixed } Key value for "params" array.
		 * @return { array } Numerically indexed array of values.
		 */
		
		#define pbuild(%v) set params($increment(params)) = %v
		
		/*--------------------------------------------------------------------*/
		
		; Initialze the return value:
		set return = ##class(%ListOfObjects).%New()
		
		; Check required arguments:
		if ($isobject(story) && $length(position)) {
			
			; Get RULE debug:
			set debug = ##class(dt.cms.support.Rules).getDebug()
			
			; Setup "params" array for required input parameters:
			; WARNING: Must be called in order that they appear in SQL statement!
			$$$pbuild(items)
			$$$pbuild(story.%Id())
			$$$pbuild(position)
			
			; Start building the query:
			set sql = "SELECT TOP ? CMSPicture " _ 
			          "FROM dt_cms_schema.CMSPictureMapping cmspm, dbo.ForeignDbLink fdbl, dbo.FileHeader fhdr " _ 
			          "WHERE cmspm.cmsStory = ? " _ 
			          "AND cmspm.position = ? " _  
			          "AND fdbl.fileheaderId = CMSPicture->fileheaderID " _ 
			          "AND fhdr.fileheaderId = CMSPicture->fileheaderID "
			
			; Includes?
			if ($length(include)) {
				
				; Convert comma delimited string of CMSPicture priorit(y/ies) "indludes" into a $list:
				$$$lister(include)
				
				; Add include list to params:
				$$$pbuild(include)
				
				; Amend query:
				set sql = sql _ "AND fhdr.priorityid %INLIST ? "
				
			}
			
			; Excludes?
			if ($length(exclude)) {
				
				; Convert comma delimited string of CMSPicture priorit(y/ies) "excludes" into a $list:
				$$$lister(exclude)
				
				; Add exclude list to params:
				$$$pbuild(exclude)
				
				; Amend query:
				set sql = sql _ "AND fhdr.priorityid NOT %INLIST ? "
				
			}
			
			; Append group by:
			set sql = sql _ "GROUP BY CMSPicture "
			
			; Append ORDER BY:
			set sql = sql _ "ORDER BY " _ $select($length(order):order, 1:"fdbl.vieworder ASC") // ORDER BY custom value OR fdbl.vieworder by default.
			
			; Output debug?
			if (debug) {
				
				; The query:
				do ##class(dt.cms.support.Rules).debugRule(debug, "sql = " _ sql)
				
				; ClassMethod arguements:
				do ##class(dt.cms.support.Rules).debugRule(debug, "##class(custom.rg.Pick).pics(story=""" _ story _ """ position=""" _ position _ """ items=""" _ items _ """ include=""" _ $listtostring(include, ", ") _ """ exclude=""" _ $listtostring(exclude, ", ") _ """ order=""" _ order _ """)")
				
			}
			
			/*
			
			SELECT TOP 5 CMSPicture 
			FROM dt_cms_schema.CMSPictureMapping cmspm, dbo.ForeignDbLink fdbl, dbo.FileHeader fhdr 
			WHERE cmspm.cmsStory = 29263427 
			AND cmspm.position = '288pxw' 
			AND fdbl.fileheaderId = CMSPicture->fileheaderID 
			AND fhdr.fileheaderId = CMSPicture->fileheaderID 
			GROUP BY CMSPicture 
			ORDER BY fdbl.vieworder ASC
			
			*/
			
			; Try/catch block required when using $$$dtThrow:
			try {
				
				; %importPackages:
				set packages = "" // Used for resolving unqualified table references (it's best, and faster, to fully qualify tables with their scheme).
				
				; No need for:
				//set rs = ##class(%ResultSet.SQL).%New() // http://docs.intersystems.com/cache20091/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_dynsql#GSQL_dynsql_resultset
				
				; Prepare and execute the query:
				set rs = ##class(%ResultSet.SQL).%Prepare(sql, .error, packages, params...) // @@UNS: Use $$$dtQueryGet(sql, params...)
				
				; An error will be a %SYSTEM.Error object:
				if ($isobject(error)) {
					
					; Throws if %sc is an error:
					$$$dtThrow($$$dtSysErr(error.Status),"Failed to execute: ##class(%ResultSet.SQL).%Prepare(""" _ $get(sql) _ """)")
					
				} else {
					
					; Initialize the status code:
					set sc = $$$OK
					
					//while (rs.%Next(.sc) && ($$$ISOK(sc))) { // Recommended to $$$ISERR() below.
					while (rs.%Next(.sc)) {
						
						; If there's a problem, exit the loop:
						quit:($$$ISERR(sc))
						
						; Return the results in a list:
						set sc = return.Insert(rs.CMSPicture) // Inserts an element with OREF value oref at the end of the list. Returns a %Status value indicating success or failure.
						
						; Throws if %sc is an error:
						$$$dtThrow(sc, "Failed to insert CMSPicture: return.Insert(" _ rs.CMSPicture _ ")")
						
					}
					
					$$$dtThrow(sc, "Failed to get query element: rs.%Next(.sc)")
					
					//do rs.Close() // Defunct. Better to use:
					kill rs // ... or set rs = ""
					
				}
				
			} catch(e) {
				
				; Throws if %sc is an error:
				$$$dtThrow(e.AsStatus(), "Something failed.")
				
			}
			
		}
		
		; Return the %ListOfObjects:
		quit return
}

}
