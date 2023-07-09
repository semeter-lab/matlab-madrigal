function version = getVersion(cgiurl, timeout)
%  getVersion  	returns a a string representing the Madrigal version
%
%  inputs:  cgiurl (string) to Madrigal site cgi directory
%      (Example: 'http://madrigal.haystack.mit.edu/cgi-bin/madrigal/')
%      Note that method getMadrigalCgiUrl converts homepage url into cgiurl.
%
%  output:
%    version - a atring representing the Madrigal version.
%
% Returns 2.5 if Madrigal does not contain the getVersion service
%
%  Example:
%  version = getVersion('http://madrigal.haystack.mit.edu/cgi-bin/madrigal/')
%
% Written by Bill Rideout (brideout@haystack.mit.edu)
%  $Id: getVersion.m 5818 2016-09-23 20:08:37Z brideout $

arguments
    cgiurl (1,1) string
    timeout (1,1) {mustBePositive} = 15.0
end

% build the complete cgi string
cgiurl = cgiurl + "getVersionService.py";

% make sure any + replaced by %2B
cgiurl = strrep(cgiurl, "+", "%2B");

% now get that url
these_options = weboptions(Timeout=timeout, ContentType="text");
version = webread(cgiurl, these_options);

end
