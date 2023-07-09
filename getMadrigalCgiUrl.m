function cgiUrl = getMadrigalCgiUrl(url)
%  getMadrigalCgiUrl  	parse the main madrigal page to get the cgi url
%
%  With Madrigal 3, this method simply returns the original url.
%
%  input: url to Madrigal
%
%  output: cgi url for that Madrigal Site
%
%  Note: parses the homepage for the accessData link
arguments
  url (1,1) string
end

% get main page
if ~any(endsWith(url, ["/", "index.html"]))
  url = url + "/";
end

these_options = weboptions('ContentType', 'text');
pagedata = webread(url, these_options);

% get host name
if startsWith(url, "http://")
    url = extractAfter(url, 7);
end
if startsWith(url, "https://")
    url = extractAfter(url, 8);
end
host = strtok(url,'/');
[host, port] = strtok(host,':');

index1 = regexp(pagedata, '[^"]*accessData.cgi');
% check for error
if isempty(index1)
    err.message = 'No Madrigal home page found at given url';
    err.identifier = 'madmatlab:badArguments';
    rethrow(err);
end
index2 = regexp(pagedata, 'accessData.cgi');
cgiUrl = "http://" +  host + port + pagedata(index1:index2-1);

end
