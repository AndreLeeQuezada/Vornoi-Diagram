abstract type Face end

struct Punkt
    x::Float64
    y::Float64
end

mutable struct Kante
    origin::Punkt
    twin::Union{Kante, Nothing}
    next::Union{Kante, Nothing}
    prev::Union{Kante, Nothing}
    face::Union{Face, Nothing}
end

mutable struct Dreieck <: Face
    edge::Kante
end

mutable struct Delaunay
    triangles::Set{Dreieck}
    limit_triangle::Dreieck
end

function create_limit_triangle(n::Float64)
    # Punkte außerhalb des Bereichs [0, n] × [0, n]
    p1 = Punkt(-100.0, -100.0)
    p2 = Punkt(n + 100.0, -100.0)
    p3 = Punkt(-100.0, n + 100.0)

    # Erstelle die drei Kanten
    e1 = Kante(p1, nothing, nothing, nothing, nothing)
    e2 = Kante(p2, nothing, nothing, nothing, nothing)
    e3 = Kante(p3, nothing, nothing, nothing, nothing)

    # Setze die Referenzen (gegen den Uhrzeigersinn)
    e1.twin = e2
    e2.twin = e3
    e3.twin = e1

    e1.next = e2
    e2.next = e3
    e3.next = e1

    e1.prev = e3
    e2.prev = e1
    e3.prev = e2

    # Erstelle das Dreieck mit der ersten Kante
    triangle = Dreieck(e1)

    # Weise die Flächen zu
    e1.face = triangle
    e2.face = triangle
    e3.face = triangle

    return triangle
end

# Funktion zum Initialisieren von Delaunay mit dem limit_triangle
function start_delaunay(n::Float64)
    lim_tri = create_limit_triangle(n)
    delaunay = Delaunay(Set([lim_tri]), lim_tri)
    return delaunay
end

function insert_point!(p::Punkt, d::Delaunay)
    # Schritt 1: Finde das Dreieck, das den Punkt p enthält
    abc = find_triangle(p, d)  # Platzhalter, nimmt an, dass es existiert und ein Dreieck zurückgibt
    if abc === nothing && !isempty(d.triangles)
        error("Gibt kein Dreieck mit Punkt $p")
    elseif abc === nothing
        # Verwende limit_triangle als Start (nur für den ersten Punkt)
        abc = d.limit_triangle
    end

    # Schritt 2: Erhalte die Kanten des Dreiecks abc
    e1 = abc.edge
    e2 = e1.next
    e3 = e2.next

    # Punkte des Dreiecks abc
    a = e1.origin
    b = e2.origin
    c = e3.origin

    # Schritt 3: Erstelle neue Dreiecke (abp, bcp, cap)
    # Kanten für abp
    e_abp1 = Kante(a, nothing, nothing, nothing, nothing)
    e_abp2 = Kante(b, nothing, nothing, nothing, nothing)
    e_abp3 = Kante(p, nothing, nothing, nothing, nothing)

    e_abp1.twin = e_abp2
    e_abp2.twin = e_abp3
    e_abp3.twin = e_abp1

    e_abp1.next = e_abp2
    e_abp2.next = e_abp3
    e_abp3.next = e_abp1

    e_abp1.prev = e_abp3
    e_abp2.prev = e_abp1
    e_abp3.prev = e_abp2

    tri_abp = Dreieck(e_abp1)
    e_abp1.face = tri_abp
    e_abp2.face = tri_abp
    e_abp3.face = tri_abp

    # Kanten für bcp
    e_bcp1 = Kante(b, nothing, nothing, nothing, nothing)
    e_bcp2 = Kante(c, nothing, nothing, nothing, nothing)
    e_bcp3 = Kante(p, nothing, nothing, nothing, nothing)

    e_bcp1.twin = e_bcp2
    e_bcp2.twin = e_bcp3
    e_bcp3.twin = e_bcp1

    e_bcp1.next = e_bcp2
    e_bcp2.next = e_bcp3
    e_bcp3.next = e_bcp1

    e_bcp1.prev = e_bcp3
    e_bcp2.prev = e_bcp1
    e_bcp3.prev = e_bcp2

    tri_bcp = Dreieck(e_bcp1)
    e_bcp1.face = tri_bcp
    e_bcp2.face = tri_bcp
    e_bcp3.face = tri_bcp

    # Kanten für cap
    e_cap1 = Kante(c, nothing, nothing, nothing, nothing)
    e_cap2 = Kante(a, nothing, nothing, nothing, nothing)
    e_cap3 = Kante(p, nothing, nothing, nothing, nothing)

    e_cap1.twin = e_cap2
    e_cap2.twin = e_cap3
    e_cap3.twin = e_cap1

    e_cap1.next = e_cap2
    e_cap2.next = e_cap3
    e_cap3.next = e_cap1

    e_cap1.prev = e_cap3
    e_cap2.prev = e_cap1
    e_cap3.prev = e_cap2

    tri_cap = Dreieck(e_cap1)
    e_cap1.face = tri_cap
    e_cap2.face = tri_cap
    e_cap3.face = tri_cap

    # Schritt 4: Entferne das ursprüngliche Dreieck (abc)
    if abc !== d.limit_triangle  # Wir entfernen das limit_triangle nicht
        delete!(d.triangles, abc)
    end

    # Schritt 5: Füge die neuen Dreiecke hinzu
    push!(d.triangles, tri_abp)
    push!(d.triangles, tri_bcp)
    push!(d.triangles, tri_cap)

    # Schritt 6: Wende recursive_flip! auf die neuen Kanten an
    recursive_flip!(e_abp2, d)  # Kante ab
    recursive_flip!(e_bcp2, d)  # Kante bc
    recursive_flip!(e_cap2, d)  # Kante ca

    return nothing
end

function flip!(e::Kante, d::Delaunay)
    # Erhalte die Flächen (Dreiecke) auf beiden Seiten der Kante e
    face1 = e.face
    face2 = e.twin.face

    # Erhalte die Punkte der Dreiecke
    # Wir gehen davon aus, dass face1 und face2 Dreieck sind
    edge1 = face1.edge
    edge2 = face2.edge

    # Finde die gegenüberliegenden Punkte (p und q) in den Dreiecken
    p = edge1.origin  # Punkt der ursprünglichen Kante
    q = e.twin.next.origin  # Gegenüberliegender Punkt im Dreieck von face2

    # Erstelle neue Kanten für die neuen Dreiecke (p-q-c und q-p-b)
    # Zuerst benötigen wir die aktuellen Kanten um e herum
    next_e = e.next
    prev_e = e.prev
    next_twin = e.twin.next
    prev_twin = e.twin.prev

    # Erstelle neue Kante e_new (q -> p)
    e_new = Kante(q, e.twin, next_e, prev_twin, face1)
    e_new.twin = Kante(p, e, next_twin, prev_e, face2)

    # Aktualisiere die Referenzen
    e_new.next.next = e_new
    e_new.twin.next.next = e_new.twin
    e_new.prev = e_new.twin
    e_new.twin.prev = e_new

    # Aktualisiere die Flächen mit den neuen Kanten
    face1.edge = e_new
    face2.edge = e_new.twin

    # Das Entfernen der alten Kante (e) ist nicht explizit erforderlich,
    # da die Referenzen aktualisiert wurden
end

# Funktion zur rekursiven Durchführung eines Flips
function recursive_flip!(e::Kante, d::Delaunay)
    # Überprüfe, ob ein Flip notwendig ist (Platzhalter für check_umkreis) Yana!
    if check_umkreis(e)  # Wir nehmen an, dass true zurückgegeben wird, wenn der Flip notwendig ist
        flip!(e, d)
        recursive_flip!(e.next, d)    # Überprüfe die neue Kante nach dem Flip
        recursive_flip!(e.twin.next, d)  # Überprüfe die gegenüberliegende Kante
    end
    return nothing
end