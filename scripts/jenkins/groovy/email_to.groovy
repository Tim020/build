<%
def authors = ""

def distro = build.environment["DISTRO"]
if (distro == "centos7") {
    authors = "build-team@couchbase.com,eric.cooper@couchbase.com"
}
%>

${authors}
