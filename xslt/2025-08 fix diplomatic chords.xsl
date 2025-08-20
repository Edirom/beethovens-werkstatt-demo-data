<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:mei="http://www.music-encoding.org/ns/mei"
    xmlns:local="local"
    exclude-result-prefixes="xs math mei local"
    version="3.0">
    <!-- 
        This XSLT fixes chords in annotated transcripts
        
        For pragmatic reasons, in Facsimile Explorer, we assume that for 
        Notirungsbuch K, our AT always have the same number of notes in a chord
        than the corresponding DT. We also accept the compromise that all shapes
        are attached to the chord using @facs, so no individual @facs are given
        for individual child notes. This means that 
    
    -->
    <xsl:output method="xml" indent="yes"/>
    
    <xsl:variable name="path.in" select="document-uri(/)" as="xs:string"/>
    <xsl:variable name="path.out" select="replace($path.in, '/sources/', '/out/sources/')"/>
    <xsl:param name="debug" select="false()" as="xs:boolean"/>
    
    <xsl:function name="local:getIndex" as="xs:integer">
        <xsl:param name="note" as="element(mei:note)"/>
        <xsl:variable name="oct" select="xs:integer($note/@oct) * 12" as="xs:integer"/>
        <xsl:variable name="pitches" select="('c', 'd', 'e', 'f', 'g', 'a', 'b')" as="xs:string+"/>
        <xsl:variable name="pname" select="$pitches => index-of($note/@pname)" as="xs:integer"/> 
        <xsl:sequence select="sum($oct, $pname)"/>
    </xsl:function>
    
    <xsl:template match="/">
        <xsl:if test="not($path.in => contains('out')) and .//mei:chord[not(@corresp)][.//mei:note/@corresp]">
            <xsl:result-document href="{$path.out}">
                <xsl:choose>
                    <xsl:when test=".//mei:chord[not(@corresp)][.//mei:note/@corresp]">
                        <xsl:apply-templates select="node()"/>        
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="/"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="mei:chord[not(@corresp)][.//mei:note/@corresp]">
        <xsl:variable name="corresp1" select="(.//mei:note/@corresp)[1]" as="xs:string"/>
        <xsl:variable name="correspPathRel" select="$corresp1 => substring-before('#')" as="xs:string"/>
        <xsl:variable name="path.base" select="$path.in => replace('/[^/]*$', '') || '/'" as="xs:string"/>
        <xsl:variable name="correspDocPath" select="$path.base || $correspPathRel" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="doc-available($correspDocPath)">
                <xsl:variable name="correspDoc" select="doc($correspDocPath)" as="node()+"/>
                <xsl:variable name="refId" select="$corresp1 => substring-after('#')" as="xs:string"/>
                <xsl:variable name="refNote" select="$correspDoc/id($refId)" as="element(mei:note)?"/>
                
                <xsl:choose>
                    <xsl:when test="exists($refNote)">
                        <xsl:variable name="dtChord" select="$refNote/ancestor-or-self::mei:chord[1]" as="element(mei:chord)"/>
                        
                        <xsl:variable name="atNotes" as="element(mei:note)+">
                            <xsl:perform-sort select=".//mei:note">
                                <xsl:sort select="local:getIndex(.)" data-type="number" order="ascending"/>
                            </xsl:perform-sort>
                        </xsl:variable>
                        <xsl:variable name="dtNotes" as="element(mei:note)+">
                            <xsl:perform-sort select="$dtChord//mei:note">
                                <xsl:sort select="xs:integer(@loc)" data-type="number" order="ascending"/>
                            </xsl:perform-sort>
                        </xsl:variable>
                        
                        <xsl:if test="count($atNotes) ne count($dtNotes)">
                            <xsl:message select="'ERROR: Not the same number of notes in DT (' || count($dtNotes) || ') and AT (' || count($atNotes) || ') at ' || ($path.in => tokenize('/'))[last()]"/>
                            <xsl:message select="$dtNotes"/>
                            <xsl:message select="$atNotes"/>
                        </xsl:if>
                        
                        <xsl:variable name="pairings" as="node()+">
                            <xsl:for-each select="$atNotes">
                                <xsl:variable name="atNote" select="." as="element(mei:note)"/>
                                <xsl:variable name="pos" select="position()" as="xs:integer"/>
                                <xsl:variable name="dtNote" select="$dtNotes[$pos]" as="element(mei:note)"/>
                                <pair at="{$atNote/@xml:id}" dt="{$correspPathRel || '#' || $dtNote/@xml:id}"/>
                            </xsl:for-each>
                        </xsl:variable>
                        
                        <xsl:copy>
                            <xsl:apply-templates select="@*"/>
                            <xsl:attribute name="corresp" select="$correspPathRel || '#' || $dtChord/@xml:id"/>
                            <xsl:apply-templates select="node()" mode="addCorresps">
                                <xsl:with-param name="pairings" select="$pairings" tunnel="yes" as="element(pair)+"/>
                            </xsl:apply-templates>
                        </xsl:copy>
                        
                        <xsl:if test="$debug or true()">
                            <xsl:message select="'Modified chord at ' || ($path.in => tokenize('/'))[last()] || '#' || @xml:id"/>    
                        </xsl:if>
                    </xsl:when>
                    <xsl:otherwise>
                        <!--<xsl:message terminate="no" select="'Problem: Unable to find reference at ' || $corresp1 || ' in ' || ($path.in => tokenize('/'))[last()] || '. Removing references.'"/>-->
                        <xsl:copy>
                            <xsl:apply-templates select="node() | @*" mode="removeBrokenCorresp"/>
                        </xsl:copy>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes" select="'ERROR: Unable to find document ' || $correspDocPath"/>
                <xsl:next-match/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="mei:note" mode="addCorresps">
        <xsl:param name="pairings" tunnel="yes" as="element(pair)+"/>
        <xsl:variable name="id" select="@xml:id" as="xs:string"/>
        <xsl:variable name="corresp" select="$pairings[@at = $id]/@dt" as="xs:string"/>
        <xsl:copy>
            <xsl:apply-templates select="@* except @corresp" mode="#current"/>
            <xsl:attribute name="corresp" select="$corresp"/>
            <xsl:apply-templates select="node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="mei:note/@corresp" mode="removeBrokenCorresp"/>
    <xsl:template match="mei:chord/@corresp" mode="removeBrokenCorresp"/>
    
    <xsl:template match="node() | @*" mode="#all">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>