############################################
# �����o�̓f�[�^���o����                   #
# Ver=0.5 2010/02/20                       #
############################################
package data_extractor;
use strict;
use File::Basename;
use Cwd;

###################################################################################################
#   ���� ���o�Ώۃt�@�C����` ����                                                                #
###################################################################################################
sub new {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �N���X��                                                                #
    #         $_[1] = ���̓f�[�^���                                                          #
    #                 �E�ϐ��w��    �j�ϐ���                                                  #
    #                 �E�t�@�C���w��jfile:�t�@�C����                                         #
    #         $_[2] = ���[�U�w��ő�o�b�t�@��                                                #
    # ���� �F ���̓f�[�^�`�F�b�N�A�I�u�W�F�N�g��`�i���o�Ώۃt�@�C����`�j                    #
    # �ԋp �F �I�u�W�F�N�g                                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $class         = shift;
    # ���͏��
    my @in_data       = ();
    my @in_index      = ();
    # ���o�������
    my @cond_data     = ();
    my $cond_index    = -1;
    my $next_index    = 0;
    # �o�b�t�@���
    my @buff_data     = ();
    my @cond_buf_max  = ();
    my $user_buf_max  = 0;
    # seek���
    my $seek_kbn      = '';
    my $seek_index    = 0;
    my @seek_num      = ();
    my $get_kbn       = '';
    my $get_index     = 0;
    my @get_num       = ();
    # pipe���
    my @pipe_data     = ();
    # �o�͏��
    my @mid_data      = ();
    my $user_out_kbn  = '';
    my @out_index     = ();
    
    # ���̓f�[�^�`�F�b�N
    @in_data = &check_in_data($_[0]);
    # ���[�U�w��ő�o�b�t�@���`�F�b�N
    $user_buf_max = &check_user_buf_max($_[1]);
    
    ####################
    # �I�u�W�F�N�g��` #
    ####################
    my $job = {
             # ���͏��
               "in_kbn"        =>$in_data[0],                 # ���͋敪�i�t�@�C��or�ϐ��j
               "in_name"       =>$in_data[1],                 # ���̓f�[�^���i�t�@�C����or�ϐ����j
               "in_index"      =>\@in_index,                  # ���͍s�ԍ�
             # ���o�������
               "cond_data"     =>\@cond_data,                 # ���o����
               "cond_index"    =>$cond_index,                 # ���o�ʒu�i���o�����̔z��index�j
               "next_index"    =>$next_index,                 # next���o����index�i���o�����̔z��index�j
             # buff���
               "buff_data"     =>\@buff_data,                 # �o�b�t�@���
               "cond_buf_max"  =>\@cond_buf_max,              # ��^�w��ő�o�b�t�@��
               "user_buf_max"  =>$user_buf_max,               # ���[�U�w��ő�o�b�t�@��
             # seek���
               "seek_kbn"      =>$seek_kbn,                   # seek�敪�i"buff"���o�b�t�@���/"input"������pipe���/"org"���I���W�i�����j
               "seek_index"    =>$seek_index,                 # seek�ʒu�i�o�b�t�@���̔z��index�j
               "seek_num"      =>\@seek_num,                  # seek�s���i�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A�擾�敪�ibuff/input/org�j�j
               "get_kbn"       =>$get_kbn,                    # get�敪�i"buff"���o�b�t�@���/"input"������pipe���/"org"���I���W�i�����j
               "get_index"     =>$get_index,                  # get�ʒu�i�o�b�t�@���̔z��index�j
               "get_num"       =>\@get_num,                   # get�s���i�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A�擾�敪�j
             # pipe���
               "pipe_data"     =>\@pipe_data,                 # pipe���i�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A�o�͋敪�A���o�Ώۃf�[�^�j
             # �o�͏��
               "mid_data"      =>\@mid_data,                  # ���[�U��s�o�͏��
               "user_out_kbn"  =>$user_out_kbn,               # ���[�U�o�͋敪�i"output"�����[�U�o�͍�/"seek"�����[�U�o�͌��seek�j
               "out_index"     =>\@out_index};                # �o�̓f�[�^index
    bless $job;
    return $job;
}
###################################################################################################
#   ���� ���̓f�[�^�`�F�b�N ����                                                                  #
###################################################################################################
sub check_in_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓f�[�^���                                                          #
    # ���� �F �ϐ��w��    �j�ϐ����݃`�F�b�N�A�f�[�^���݃`�F�b�N                              #
    #         �t�@�C���w��j�t�@�C�����݃`�F�b�N�A�Ǎ��݌����`�F�b�N�A�f�[�^���݃`�F�b�N      #
    # �ԋp �F �`�F�b�N����̓f�[�^���i���͋敪�A���̓f�[�^���j                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $in_data  = shift;                                                                     # ���̓f�[�^���
    my @out_data = ();                                                                        # �`�F�b�N����̓f�[�^���(���͋敪�A���̓f�[�^��)
    
    # �t�@�C���w�肩�ϐ��w�肩�`�F�b�N
    if ($in_data !~ /file:/) {
        #==========#
        # �ϐ��w�� #
        #==========#
        # ���[�U�X�N���v�g��`�ϐ��ɒu������
        $out_data[1] = '${main::'.$in_data.'}';
        # �ϐ��`�F�b�N
        if (! defined eval($out_data[1])) {
            #----------#
            # �ϐ��Ȃ� #
            #----------#
            print STDERR "Input variable($in_data) not found\n";
            exit 99;
        } elsif (eval($out_data[1]) eq '') {
            #--------------#
            # �ϐ��ɒl�Ȃ� #
            #--------------#
            print STDERR "There are not the input data($in_data)\n";
            exit 99;
        }
    } else {
        #==============#
        # �t�@�C���w�� #
        #==============#
        $out_data[0] = 'file';
        $out_data[1] = substr $in_data, 5;
        # �t�@�C���`�F�b�N
        if (!-e "$out_data[1]") {
            #--------------#
            # �t�@�C���Ȃ� #
            #--------------#
            print STDERR "Input file($in_data) not found\n";
            exit 99;
        } elsif (!-r "$out_data[1]") {
            #----------------#
            # �Ǎ��݌����Ȃ� #
            #----------------#
            print STDERR "Input file($in_data) is not read authority\n";
            exit 99;
        }
        my @in_file_information = stat $out_data[1];
        if ($in_file_information[7] == 0) {
            #------------#
            # �f�[�^�Ȃ� #
            #------------#
            print STDERR "There are not the input data($in_data)\n";
            exit 99;
        }
    }
    
    ################################
    # �`�F�b�N����̓f�[�^���ԋp #
    ################################
    return @out_data;
}
###################################################################################################
#   ���� ���[�U�w��ő�o�b�t�@���`�F�b�N ����                                                    #
###################################################################################################
sub check_user_buf_max {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���[�U�w��ő�o�b�t�@��                                                #
    # ���� �F ���l�`�F�b�N                                                                    #
    # �ԋp �F �`�F�b�N�テ�[�U�w��ő�o�b�t�@��                                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $user_buf_max = shift;                                                                 # ���[�U�w��ő�o�b�t�@��
    
    ####################################
    # ���[�U�w��ő�o�b�t�@���`�F�b�N #
    ####################################
    # ���[�U�w��ő�o�b�t�@�������w�肩�`�F�b�N
    if ($user_buf_max eq '') {
        #==========#
        # �w��Ȃ� #
        #==========#
        return 0;
    # ���[�U�w��ő�o�b�t�@���������w�肩�`�F�b�N
    } elsif ($user_buf_max =~ /^\d+$/) {
        #======#
        # ���� #
        #======#
        return $user_buf_max;
    } else {
        #========#
        # ���̑� #
        #========#
        # ���[�U�w��ő�o�b�t�@���Ɍ��
        print STDERR "Greatest Seek Buffers Number is an Error($user_buf_max)\n";
        exit 99;
    }
}
###################################################################################################
#   ���� ���o������` ����                                                                        #
###################################################################################################
sub condition {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #         $_[1�`]= ���o�f�[�^�w��                                                         #
    # ���� �F ���o�����`�F�b�N�A���o�����ݒ�A���o�����ɕK�v�Ȕz��̓o�^                      #
    #-----------------------------------------------------------------------------------------#
    # ���o�f�[�^�w��                                                                          #
    #   �s���o                                                                                #
    #     �s�ԍ��w��  �F[!]L/{�s�ԍ�|end[-�͈�]}                                              #
    #                 �F[!]L/{�s�ԍ�|end[-�͈�]}//�񒊏o                                      #
    #                 �F[!]L/{�s�ԍ�|end[-�͈�]}/{�I���s�ԍ�|{+|-}�͈�|end[-�͈�]}            #
    #                 �F[!]L/{�s�ԍ�|end[-�͈�]}/{�I���s�ԍ�|{+|-}�͈�|end[-�͈�]}/�񒊏o     #
    #     ���K�\���w��F[!]LR/���o����                                                        #
    #                 �F[!]LR/���o����//�񒊏o                                                #
    #                 �F[!]LR/���o����/{�I������|{+|-}�͈�}                                   #
    #                 �F[!]LR/���o����/{�I������|{+|-}�͈�}/�񒊏o                            #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #     ���ŏI�s�̒��o�́A"end"���w��                                                       #
    #   �񒊏o                                                                                #
    #     ��ԍ��w��  �F[!]C/{��ԍ�|end[-�͈�]}                                              #
    #                 �F[!]C/{��ԍ�|end[-�͈�]}/{�I����ԍ�|{+|-}�͈�|end[-�͈�]}            #
    #     ���K�\���w��F[!]CR/���o����                                                        #
    #                 �F[!]CR/���o����/{�I������|{+|-}�͈�}                                   #
    #     �������ȊO�̒��o�́A�擪��"!"��t�^                                                 #
    #     ���ŏI��̒��o�́A"end"���w��                                                       #
    #   ���[�U���o    �F�m"�p�b�P�[�W��::�T�u���[�`����"[, "���[�U����", ��� ]�n              #
    #                   ����O�́m�n�́A�z���`���Ӗ�����                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj          = $_[0];                                                                 # �I�u�W�F�N�g
    my $cond_buf_max = -1;                                                                    # ��^�w��ő�o�b�t�@��(�����l=-1)
    
    ####################
    # ���o�����`�F�b�N #
    ####################
    my @cond_data = &check_extraction_cond(@_);
    
    ##############################
    # ��^�w��o�b�t�@���`�F�b�N #
    ##############################
    # ��^���o����(�s�ԍ��w��A���}�C�i�X�t�������͈̔�)�����^�w��ő�o�b�t�@�����m��
    foreach my $cond(grep { (${$_}[0] eq 'L' and  ${$_}[2] =~ /^end-\d+$/)
                         or (${$_}[0] =~ /L/ and (${$_}[3] =~ /^-\d+$/ or ${$_}[3] =~ /^end-\d+$/)) }@cond_data) {
         my $cond2    = 0;
         my $cond3    = 0;
         my $cond_min = 0;
         # ��ԏ������l�͈̔͂��u��^�w��ő�o�b�t�@���v�ɐݒ�
         if (${$cond}[2] =~ /^end(-\d+)$/) {
             $cond2 = $1;
         }
         if (${$cond}[3] =~ /^end(-\d+)$/) {
             $cond3 = $1;
         }
         if ($cond2 <= $cond3) {
             $cond_min = $cond2;
         } else {
             $cond_min = $cond3;
         }
         if (${$cond}[3] =~ /^-\d+$/) {
             $cond_min += ${$cond}[3];
         }
         if ($cond_buf_max > $cond_min) {
             $cond_buf_max = $cond_min;
         }
    }
    
    ############
    # �z��o�^ #
    ############
    push(@{$obj->{cond_data}}, [@cond_data]);                                                 # ���o�����𒊏o����(�z��)�֓o�^
    push(@{$obj->{cond_buf_max}} , ($cond_buf_max * -1));                                     # �ő�o�b�t�@�������������Ē�^�w��ő�o�b�t�@��(�z��)�֓o�^
    push(@{$obj->{pipe_data}}, []);                                                           # pipe���(�z��)�֘g�̂ݓo�^
    push(@{$obj->{buff_data}}, []);                                                           # �o�b�t�@���(�z��)�֘g�̂ݓo�^
    push(@{$obj->{mid_data}} , []);                                                           # ���[�U��s�o�͏��(�z��)�֘g�̂ݓo�^
}
###################################################################################################
#   ���� �G�C���A�X���o������` ����                                                              #
###################################################################################################
# ���s���o��
sub extract_line {
    &set_condition('nn', 'L', @_);
}
sub extract_line_nn {
    &set_condition('nn', 'L', @_);
}
sub extract_line_nr {
    &not_support_command();
}
sub extract_line_r {
    &set_condition('rn', 'LR', @_);
}
sub extract_line_rn {
    &set_condition('rn', 'LR', @_);
}
sub extract_line_rr {
    &set_condition('rr', 'LR', @_);
}
# ���񒊏o��
sub extract_column {
    &set_condition('nn', 'C', @_);
}
sub extract_column_nn {
    &set_condition('nn', 'C', @_);
}
sub extract_column_nr {
    &not_support_command();
}
sub extract_column_r {
    &set_condition('rn', 'CR', @_);
}
sub extract_column_rn {
    &set_condition('rn', 'CR', @_);
}
sub extract_column_rr {
    &set_condition('rr', 'CR', @_);
}
# ���ے�s���o��
sub remove_line {
    &set_condition('nn', '!L', @_);
}
sub remove_line_nn {
    &set_condition('nn', '!L', @_);
}
sub remove_line_nr {
    &not_support_command();
}
sub remove_line_r {
    &set_condition('rn', '!LR', @_);
}
sub remove_line_rn {
    &set_condition('rn', '!LR', @_);
}
sub remove_line_rr {
    &set_condition('rr', '!LR', @_);
}
# ���ے�񒊏o��
sub remove_column {
    &set_condition('nn', '!C', @_);
}
sub remove_column_nn {
    &set_condition('nn', '!C', @_);
}
sub remove_column_nr {
    &not_support_command();
}
sub remove_column_r {
    &set_condition('rn', '!CR', @_);
}
sub remove_column_rn {
    &set_condition('rn', '!CR', @_);
}
sub remove_column_rr {
    &set_condition('rr', '!CR', @_);
}
sub not_support_command {
    my $this = (caller 1)[3];
    $this =~ s/.*:://;
    print STDERR "not yet support ($this)\n";
    exit 99;
}
sub set_condition {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �w��敪�in�Ar�j                                                       #
    #         $_[1]  = �ݒ�敪�iL�ALR�AC�ACR�j                                               #
    #         $_[2]  = �I�u�W�F�N�g                                                           #
    #         $_[3�`]= ���o�f�[�^�w��[, ���o�f�[�^�w��[,���]]                                 #
    # ���� �F ���o�敪�̕t�^�A���o������`                                                    #
    #-----------------------------------------------------------------------------------------#
    # ���o�f�[�^�w��                                                                          #
    #   nn �F  {�s�ԍ�|end[-�͈�]}                                                            #
    #        [ {�s�ԍ�|end[-�͈�]}[,{�I���s�ԍ�|{+|-}�͈�|end[-�͈�]}] ]                      #
    #   rn �F  ���o����                                                                       #
    #        [ ���o����[,{{+|-}�͈�|end[-�͈�]}] ]                                            #
    #   rr �F  ���o����                                                                       #
    #        [ ���o����[,�I������] ]                                                          #
    #   ����O�́m�n�́A�z���`���Ӗ�����                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $in_kbn       = shift;                                                                 # �w��敪
    my $set_kbn      = shift;                                                                 # �ݒ�敪
    my $obj          = shift;                                                                 # �I�u�W�F�N�g
    my @conds        = ();                                                                    # ���o����
    
    foreach my $cond(@_) {
        if ($cond =~ /^ARRAY\(.*\)/) {
            if ($in_kbn eq 'rn') {
                if (${$cond}[1] =~ /^\d+$/) {
                    ${$cond}[1] = '+'.${$cond}[1];
                } elsif (${$cond}[1] !~ /^[\+-]\d+$/) {
                    # ���o�͈͌��
                    print STDERR "End Range Number is an Error (${$cond}[1])\n";
                    exit 99;
                }
            }
            if ($in_kbn eq 'rr' and ${$cond}[1] =~ /^-/) {
                ${$cond}[1] = '\\'.${$cond}[1];
            }
            push(@conds, "$set_kbn/${$cond}[0]/${$cond}[1]");
        } else {
            push(@conds, "$set_kbn/$cond");
        }
    }
    ################
    # ���o������` #
    ################
    &condition($obj, @conds);
}
###################################################################################################
#   ���� ���o�����`�F�b�N ����                                                                    #
###################################################################################################
sub check_extraction_cond {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #         $_[1�`]= ���o����                                                               #
    #                  ���ڍׂ́A���o������`�̐������Q��                                     #
    # ���� �F ���o�����`�F�b�N�A��^���o�����̋L�q�`�F�b�N                                    #
    # �ԋp �F �`�F�b�N�㒊�o����                                                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj           = shift;                                                                # �I�u�W�F�N�g
    my @in_cond_data  = @_;                                                                   # ���o����
    my @out_cond_data = ();                                                                   # �`�F�b�N�㒊�o����
    my $line_max      = 0;                                                                    # ���o�Ώۃt�@�C���̃��R�[�h��
    # ���o�Ώۃt�@�C���̃��R�[�h���擾
    if ($^O eq 'linux' and $#{$obj->{cond_data}} eq -1) {
        $line_max     = &get_line_max($obj);
    }
    
    ####################
    # ���o�����`�F�b�N #
    ####################
    # ���o�������L�q���[���ɍ����Ă��邩�`�F�b�N
    foreach my $cond(@in_cond_data) {
        # ��^���o("L/LR/C/CR")���`�F�b�N
        if ($cond =~ /^\!{0,1}[CLcl][Rr]*\//) {
            #==========#
            # ��^���o #
            #==========#
            # ���o�������X���b�V��("/")��؂�ŕ���
            my @in_cond = split /[\/]/, $cond;                                                # �����㒊�o����
            #**************************************************************************************#
            # �������㒊�o�����̏ڍׁ�                                                             #
            # ${$in_cond}[0] �F ���o���1(�m��ے�敪�{���o�敪)                                  #
            # ${$in_cond}[1] �F �J�n����1(�s�ԍ�/��ԍ�/end[-�͈�]/���o����)                       #
            # ${$in_cond}[2] �F[�I������1(�I���s�ԍ�/�I����ԍ�/{+|-}�͈�/end[-�͈�]/�I������)]    #
            # ${$in_cond}[3] �F[���o���2(�m��ے�敪�{���o�敪)]                                 #
            # ${$in_cond}[4] �F[�J�n����2(��ԍ�/end[-�͈�]/���o����)]                             #
            # ${$in_cond}[5] �F[�I������2({+|-}�͈�/end[-�͈�]/�I������)]                          #
            #**************************************************************************************#
            my @in_kbn  = ();                                                                 # ���o�����敪
            #**************************************************************************************#
            # �����o�����敪��                                                                     #
            # ${$in_kbn}[0] �F �m��ے�敪1(�����㒊�o�����̒��o���1�̍m��ے�敪)              #
            # ${$in_kbn}[1] �F ���o�敪1(�����㒊�o�����̒��o���1�̒��o�敪)                      #
            # ${$in_kbn}[2] �F �m��ے�敪2(�����㒊�o�����̒��o���2�̍m��ے�敪)              #
            # ${$in_kbn}[3] �F ���o�敪2(�����㒊�o�����̒��o���2�̒��o�敪)                      #
            # ${$in_kbn}[4] �F �b��J�n�ʒu�i���K�\���A���ے蒊�o�������Ɏg�p�j                  #
            #**************************************************************************************#
            
            # �m�蒊�o�������ے蒊�o�������`�F�b�N
            if ((substr $in_cond[0], 0, 1) ne '!') {
                #------#
                # �m�� #
                #------#
                $in_kbn[1] = uc(substr $in_cond[0], 0);
            } else {
                #------#
                # �ے� #
                #------#
                $in_kbn[0] = substr $in_cond[0], 0, 1;
                $in_kbn[1] = uc(substr $in_cond[0], 1);
            }
            
            # ��^���o�����̋L�q�`�F�b�N
            if ($in_kbn[1] eq 'L' and $line_max > 0 and $in_cond[1] =~ /^end(-\d+)*$/) {
                my $cond1 = $1;
                $in_cond[1] = $line_max;
                if ($cond1 ne '') {
                    $in_cond[1] += $cond1;
                }
            }
            if ($in_kbn[1] =~ /L/ and $line_max > 0 and $in_cond[2] =~ /^end(-\d+)*$/) {
                my $cond2 = $1;
                $in_cond[2] = $line_max;
                if ($cond2 ne '') {
                    $in_cond[2] += $cond2;
                }
            }
            &check_fixed_form_cond($obj, $in_kbn[0], $in_kbn[1], $in_cond[1], $in_cond[2]);
            
            # ���K�\���A���ے蒊�o�������̎b��J�n�ʒu��ݒ�
            if ($in_kbn[1] eq 'LR' and $in_kbn[0] ne '') {
                $in_kbn[4] = '0';
            }
            
            # �񒊏o�w��("C/CR")�����邩�`�F�b�N
            if ($in_cond[3] =~ /^\!{0,1}[Cc][Rr]*$/) {
                # �m�蒊�o�������ے蒊�o�������`�F�b�N
                if ((substr $in_cond[3], 0, 1) ne '!') {
                    #������#
                    # �m�� #
                    #������#
                    $in_kbn[3] = uc(substr $in_cond[3], 0);
                } else {
                    #������#
                    # �ے� #
                    #������#
                    $in_kbn[2] = substr $in_cond[3], 0, 1;
                    $in_kbn[3] = uc(substr $in_cond[3], 1);
                }
                
                # ��^���o�����̋L�q�`�F�b�N
                &check_fixed_form_cond($obj, $in_kbn[2], $in_kbn[3], $in_cond[4], $in_cond[5]);
                
                # ���o����(�񒊏o)���`�F�b�N�㒊�o�����֓o�^
                push(@out_cond_data, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", "$in_kbn[3]", "$in_kbn[2]", "$in_cond[4]", "$in_cond[5]", "$in_kbn[4]"]);
            } elsif ($in_cond[3] eq '') {
                #--------#
                # �s���o #
                #--------#
                # ���o����(�s���o)���`�F�b�N�㒊�o�����֓o�^
                push(@out_cond_data, ["$in_kbn[1]", "$in_kbn[0]", "$in_cond[1]", "$in_cond[2]", '', '', '', '', "$in_kbn[4]"]);
            } else {
                #--------#
                # ���̑� #
                #--------#
                # ���o�敪���
                print STDERR "Extraction Division is an Error ($cond)\n";
                exit 99;
            }
        # ���[�U���o(�z��)���`�F�b�N
        } elsif ($cond =~ /^ARRAY\(.*\)/) {
            #============#
            # ���[�U���o #
            #============#
            # ���[�U�֐�("�p�b�P�[�W��::�֐���")���w�肳��Ă��邩�`�F�b�N
            if (${$cond}[0] =~ /^[^\.]+\:\:.+/) {
                #��������������������#
                # ���[�U�֐��w�肠�� #
                #��������������������#
                # ���o�敪��"USER"(���[�U���o)�Ƃ��āA���o����(���[�U���o)���`�F�b�N�㒊�o�����֓o�^
                push(@out_cond_data, ['USER', @{$cond}]);
            } else {
                #��������#
                # ���̑� #
                #��������#
                # ���o�敪���
                print STDERR "User Function Name Error (@{$cond})\n";
                exit 99;
            }
        } else {
            #========#
            # ���̑� #
            #========#
            # ���o�敪���
            print STDERR "Extraction Division is an Error ($cond)\n";
            exit 99;
        }
    }
    
    ############################
    # �`�F�b�N�㒊�o������ԋp #
    ############################
    return @out_cond_data;
}
###################################################################################################
#   ���� ���o�Ώۃt�@�C���̃��R�[�h���擾 ����                                                    #
###################################################################################################
sub get_line_max {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    # ���� �F ���o�Ώۃt�@�C���̃��R�[�h�����擾                                              #
    # �ԋp �F ���o�Ώۃt�@�C���̃��R�[�h��                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj      = shift;                                                                     # �I�u�W�F�N�g
    my $line_max = 0;                                                                         # ���R�[�h��
    
    ##################
    # ���R�[�h���擾 #
    ##################
    #my $line_max = `wc --lines $obj->{in_name}`;
    # ���s�R�[�h�����擾
    if ( `wc --lines $obj->{in_name}` =~ /^([0-9]+)/) {
        $line_max = $1;
    }
    
    # �ŏI�s�ɉ��s�R�[�h�����邩�`�F�b�N
    my $last_line = `tail -n 1 $obj->{in_name}`;
    if ((substr $last_line, -1) ne "\n") {
        $line_max++;
    }
    
    ##################
    # ���R�[�h���ԋp #
    ##################
    return $line_max;
}
###################################################################################################
#   ���� ��^���o�����̋L�q�`�F�b�N ����                                                          #
###################################################################################################
sub check_fixed_form_cond {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �m��ے�敪                                                            #
    #         $_[2] = ���o�敪                                                                #
    #         $_[3] = �J�n����(�s�ԍ�/��ԍ�/end[-�͈�]/���o����)                             #
    #         $_[4] = �I������(�I���s�ԍ�/�I����ԍ�/{+|-}�͈�/end[-�͈�]/�I������)           #
    #         ���J�b�R���́A���o������`�̐������Q��                                          #
    # ���� �F ��^���o�����̋L�q�`�F�b�N�A�͈�($_[4])���Βl�ɕϊ�                           #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $cond_kbn   = \$_[2];                                                                  # ���o�敪
    my $cond_start = \$_[3];                                                                  # �J�n����
    my $cond_end   = \$_[4];                                                                  # �I������
    
    ##############################
    # ��^���o�����̋L�q�`�F�b�N #
    ##############################
    # �w����@�Ɋ���L�q�ɂȂ��Ă��邩�`�F�b�N
    if (${$cond_kbn} !~ /R/) {
        #==========#
        # �ԍ��w�� #
        #==========#
        # ���J�n�����`�F�b�N��
        if (${$cond_start} =~ /^end(-\d+)*$/) {
            #---------------------------#
            # �ŏI����̎����w��("end") #
            #---------------------------#
            # �����Ȃ�
        } elsif (${$cond_start} =~ /^\d+$/ and ${$cond_start} > 0) {
            #----------#
            # �����w�� #
            #----------#
            # �����Ȃ�
        } elsif (${$cond_start} !~ /^[\+-]\d+$/ and ${$cond_start} !~ /[a-zA-Z]/ and ${$cond_start} =~ /[\+\-\*\/\%]/) {
            #------------#
            # �v�Z���w�� #
            #------------#
            my $cond_eval_out = undef;
            my $cond_eval     = '$cond_eval_out = '."${$cond_start}";
            ${$cond_start}    = $cond_eval_out;
        } else {
            #--------#
            # ���̑� #
            #--------#
            # �J�n�ԍ����
            print STDERR "Starting Point Number is an Error (${$cond_start})\n";
            exit 99;
        }
        
        # ���I�������`�F�b�N��
        if (${$cond_end} =~ /^end(-\d+)*$/) {
            #---------------------------#
            # �ŏI����̎����w��("end") #
            #---------------------------#
            # �����Ȃ�
        } elsif (${$cond_end} =~ /^\d+$/ and ${$cond_end} > 0) {
            #----------#
            # �����w�� #
            #----------#
            # �J�n���������I���������������ꍇ�A��������ւ���
            if (${$cond_start} =~ /end/ or ${$cond_start} > ${$cond_end}) {
                my $temp_su    = ${$cond_start};
                ${$cond_start} = ${$cond_end};
                ${$cond_end}   = $temp_su;
            }
        } elsif (${$cond_end} =~ /^\+\d+$/ and ${$cond_end} != 0) {
            #------------------------------#
            # �㑱�͈͎w��(�v���X�t������) #
            #------------------------------#
            # �J�n��"end"�ȊO�̏ꍇ�A�I�����Βl�ɕϊ�
            if (${$cond_start} !~ /end/) {
                ${$cond_end} += ${$cond_start};
            }
        } elsif (${$cond_end} =~ /^-\d+$/ and ${$cond_end} != 0) {
            #--------------------------------#
            # ��s�͈͎w��(�}�C�i�X�t������) #
            #--------------------------------#
            # �J�n��"E"�ȊO�̏ꍇ�A�l���Βl�ɕϊ����A�J�n�ƏI������ւ�
            if (${$cond_start} !~ /end/) {
                my $temp_su     = ${$cond_start};
                ${$cond_start} += ${$cond_end};
                ${$cond_end}    = $temp_su;
            }
        } elsif (${$cond_end} !~ /[a-zA-Z]/ and ${$cond_end} =~ /[\+\-\*\/\%]/) {
            #------------#
            # �v�Z���w�� #
            #------------#
            my $cond_eval_out = undef;
            my $cond_eval     = '$cond_eval_out = '."${$cond_end}";
            ${$cond_end}      = $cond_eval_out;
        } elsif (${$cond_end} eq '') {
            #----------#
            # �w��Ȃ� #
            #----------#
            # �J�n���I���ɐݒ�
            ${$cond_end} = ${$cond_start};
        } else {
            #--------#
            # ���̑� #
            #--------#
            # ���o�͈͌��
            print STDERR "End Range Number is an Error (${$cond_end})\n";
            exit 99;
        }
    } else {
        #==============#
        # ���K�\���w�� #
        #==============#
        # ���J�n�����`�F�b�N��
        if (${$cond_start} eq '') {
            # �N�_���K�\�w�茻����
            print STDERR "Regular Expression Character string is not Found\n";
            exit 99;
        }
        
        # ���I�������`�F�b�N��
        if ($_[4] =~ /^[\+-]\d+/ and ($_[4] !~ /^[\+-]\d+$/ or $_[4] == 0))  {
            # ���o�͈͌��
            print STDERR "End Range Number is an Error ($_[4])\n";
            exit 99;
        }
    }
}
###################################################################################################
#   ���� ���o���s ����                                                                            #
###################################################################################################
sub execute {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F �s�f�[�^�擾�AED�R�}���h���o���s                                                #
    # �ԋp �F ���o����                                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj       = shift;                                                                    # �I�u�W�F�N�g
    my $seek_byte = 0;                                                                        # ���R�[�hbyte�ʒu
    my $index_org = 0;                                                                        # �I���W�i���s�ԍ�
    my @index_now = ();                                                                       # ���͍s�ԍ�
    push(@{$obj->{pipe_data}}, []);                                                           # �ŏI���o���ʏo�͗p�̔z���ǉ�
    my $return_data = \@{${$obj->{pipe_data}}[$#{$obj->{pipe_data}}]};                        # �ŏI���o����
    
    ########################
    # ���o�������݃`�F�b�N #
    ########################
    if ($#{$obj->{cond_data}} < 0) {
        # ���o�����Ȃ�
        return ();
    }
    
    ################
    # �t�@�C��OPEN #
    ################
    if ($obj->{in_kbn} eq 'file') {
        # �t�@�C���w��
        &in_file_open($obj->{in_name});
    }
    
    ############
    # ���o���s #
    ############
    # �S�Ă̒��o����������܂Œ��o�i�������[�v�j
    while (1) {
        #==========#
        # �ϐ���` #
        #==========#
        my $cond_index = $obj->{cond_index};                                                  # ���o�ʒu
        my $next_index = $obj->{cond_index} + 1;                                              # next���o�ʒu
        my $in_data    = \@{${$obj->{pipe_data}}[$obj->{cond_index}]};                        # (���o�ʒu��)����pipe���
        my $out_data   = \@{${$obj->{pipe_data}}[$next_index]};                               # (���o�ʒu��)�o��pipe���
        
        #==================#
        # �f�[�^�擾�E���o #
        #==================#
        # ���o�ʒu���`�F�b�N���A���{������U�蕪����
        if ($obj->{cond_index} < 0) {
            #--------------------#
            # ���o�Ώۃf�[�^�擾 #
            #--------------------#
            &get_extraction_data($obj, \$seek_byte, \$index_org);
            # �ŏI�s�ԍ����ݒ�ł����ꍇ�A���o����("end")��������
            if (${$out_data}[$#{$out_data}] eq 'Data_Extraction_END') {
                my $cond_data = \@{${$obj->{cond_data}}[$next_index]};
                # �J�n������ϊ�
                &get_cond_l_s($index_org, grep{${$_}[0] eq 'L' and ${$_}[2] =~ /end/}@{$cond_data});
                # �I��������ϊ�
                &get_cond_l_e($index_org, grep{${$_}[0] eq 'L' and ${$_}[3] =~ /end/}@{$cond_data});
            }
        } else {
            #--------------------------#
            # ���o�ʒu��ED�R�}���h���o #
            #--------------------------#
            &watch_extraction_data($obj, \@index_now);
        }
        
        #==================#
        # ���o�I���`�F�b�N #
        #==================#
        # �SED�R�}���h���o�������������`�F�b�N
        if ($#{$return_data} >= 0 and ${$return_data}[$#{$return_data}] eq 'Data_Extraction_END') {
            #------------------------#
            # �SED�R�}���h���o������ #
            #------------------------#
            # �J��Ԃ�(while)�𔲂���
            last;
        }
        
        #======================#
        # ���񒊏o�ʒu�`�F�b�N #
        #======================#
        # �㑱ED�R�}���h���o���\���`�F�b�N
        if ($obj->{cond_index} < $#{$obj->{cond_data}} and
            # �f�[�^�擾(cond_index=-1)��
           (($obj->{cond_index} < 0                                       and $#{$out_data} > ${$obj->{cond_buf_max}}[$next_index]) or
            # ED�R�}���h���o(cond_index>=0)���A�����[�U�o�b�t�@��(user_buf_max)����cond_buf_max��
            ($obj->{user_buf_max} >= ${$obj->{cond_buf_max}}[$next_index] and $#{$out_data} > ($obj->{user_buf_max} * 2)) or
            # ED�R�}���h���o(cond_index>=0)���A����user_buf_max��cond_buf_max��
            ($obj->{user_buf_max} < ${$obj->{cond_buf_max}}[$next_index]  and $#{$out_data} > ($obj->{user_buf_max} + ${$obj->{cond_buf_max}}[$next_index])) or
            # "Data_Extraction_END"�܂ŏo�͍ώ�
            ($#{$out_data} >= 0 and ${$out_data}[$#{$out_data}] eq 'Data_Extraction_END'))) {
            #----------------------------#
            # �㑱ED�R�}���h�̒��o���\ #
            #----------------------------#
            # �㑱ED�R�}���h���o�փV�t�g
            $obj->{cond_index}++;
            # �J��Ԃ�(while)�̐擪�ɖ߂�
            next;
        }
        # ��sED�R�}���h���o�ɖ߂�ׂ����`�F�b�N(�����ł���ED�R�}���h���o�܂Ŗ߂�)
        while ($obj->{cond_index} >= 0 and
            # ���̓f�[�^�Ȃ�(in_data=-1)��
           ($#{$in_data} == -1 or
           (${$in_data}[$#{$in_data}] ne 'Data_Extraction_END' and
            # �擪ED�R�}���h���o(cond_index=0)��
           (($obj->{cond_index} == 0                                             and $#{$in_data} <= ${$obj->{cond_buf_max}}[$obj->{cond_index}]) or
            # �㑱ED�R�}���h���o(cond_index>0)���A����user_buf_max����cond_buf_max��
            ($obj->{user_buf_max} >= ${$obj->{cond_buf_max}}[$obj->{cond_index}] and $#{$in_data} <= ($obj->{user_buf_max} * 2)) or
            # �㑱ED�R�}���h���o(cond_index>0)���A����user_buf_max��cond_buf_max��
            ($obj->{user_buf_max} < ${$obj->{cond_buf_max}}[$obj->{cond_index}]  and $#{$in_data} <= ($obj->{user_buf_max} + ${$obj->{cond_buf_max}}[$obj->{cond_index}])))))) {
            #----------------------------#
            # ��ED�R�}���h�̒��o���s�\ #
            #----------------------------#
            # ��sED�R�}���h���o�փV�t�g
            $obj->{cond_index}--;
        }
    }
    
    #################
    # �t�@�C��CLOSE #
    #################
    if ($obj->{in_kbn} eq 'file') {
        # �t�@�C���w��
        &in_file_close($obj->{in_name});
    }
    
    ################
    # ���o���ʕԋp #
    ################
    return &extraction_result(@{$return_data});
}
###################################################################################################
#   ���� ���o�Ώۃf�[�^�擾 ����                                                                  #
###################################################################################################
sub get_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���R�[�hbyte�ʒu                                                        #
    #      �F $_[2] = �I���W�i���s�ԍ�                                                        #
    # ���� �F ���o�Ώۃf�[�^�擾�A���o�Ώۃf�[�^����pipe�z��֓o�^                          #
    #-----------------------------------------------------------------------------------------#
    # �����o�Ώۃf�[�^���Ƃ́A���L��z�񉻂�������                                          #
    #   �E"�I���W�i���s�ԍ�"                                                                  #
    #   �E"���R�[�hbyte�ʒu"         ���擾�敪��"�t�@�C���w��"���Ɏg�p                       #
    #   �E"���͍s�ԍ�"               �������ł́u�I���W�i���s�ԍ������͍s�ԍ��v               #
    #   �E""(null)                   �����[�U�֐��ɂĎg�p                                     #
    #   �E"���o�Ώۃf�[�^"                                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $seek_byte, $index_org) = @_;                                                   # �I�u�W�F�N�g�A���R�[�hbyte�ʒu�A�I���W�i���s�ԍ�
    
    ######################
    # ���o�Ώۃf�[�^�擾 #
    ######################
    # ���R�[�hbyte�ʒu�ֈړ�
    seek EXTRACTION_FILE, (${$seek_byte}), 0 or "$!($obj->{in_name})";
    # ���R�[�h�����擾
    my $line = &get_line_data($obj, ${$index_org});
    
    ######################
    # �擾�f�[�^�`�F�b�N #
    ######################
    # �擾�f�[�^��EOF���`�F�b�N
    if ("$line" ne 'Data_Extraction_END') {
        #============#
        # �f�[�^���� #
        #============#
        # �I���W�i���s�ԍ����J�E���gUP
        ${$index_org}++;
        # �擾�敪���`�F�b�N���Apipe�z��ւ̓o�^���@���m��
        if ($obj->{in_kbn} ne '') {
            #--------------#
            # �t�@�C���w�� #
            #--------------#
            # ���o�Ώۃf�[�^����pipe�z��֓o�^
            push(@{${$obj->{pipe_data}}[0]}, ["${$index_org}", "${$seek_byte}", "${$index_org}", '', "$line"]);
            # ���R�[�hbyte�ʒu��ޔ�
            ${$seek_byte} = (tell EXTRACTION_FILE);
        } else {
            #----------#
            # �ϐ��w�� #
            #----------#
            # ���o�Ώۃf�[�^����pipe�z��֓o�^
            push(@{${$obj->{pipe_data}}[0]}, ["${$index_org}", '', "${$index_org}", '', "$line"]);
        }
    } else {
        #=====#
        # EOF #
        #=====#
        # "Data_Extraction_END"��pipe�z��֓o�^
        push(@{${$obj->{pipe_data}}[0]}, 'Data_Extraction_END');
    }
}
###################################################################################################
#   ���� �����ʒu��ED�R�}���h���o ����                                                            #
###################################################################################################
sub watch_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F ���o����A���o�f�[�^��pipe�z��o�^                                              #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $index_now) = @_;                                                               # �I�u�W�F�N�g�A���͍s�ԍ�
    
    ################################
    # ��sED�R�}���h���o���ʂ��擾 #
    ################################
    # �����ʒu�̓���pipe����shift���Ē��o�Ώۃf�[�^�����擾
    my $line_data = shift(@{${$obj->{pipe_data}}[$obj->{cond_index}]});
    
    ######################
    # �擾�f�[�^�`�F�b�N #
    ######################
    if ("$line_data" ne 'Data_Extraction_END') {
        #============#
        # �f�[�^���� #
        #============#
        # ���͍s�ԍ����J�E���gUP
        ${$index_now}[$obj->{cond_index}]++;
        # ���o�Ώۃf�[�^���̓��͍s�ԍ����ŐV��
        ${$line_data}[2] = ${$index_now}[$obj->{cond_index}];
        # ���o�����u����
        &change_extraction_cond($obj, \@{$line_data});
        # ED�R�}���h���o����
        &check_extraction_data($obj, \@{$line_data});
    } else {
        #=====#
        # EOF #
        #=====#
        # "Data_Extraction_END"��pipe�z��֓o�^
        push(@{${$obj->{pipe_data}}[($obj->{cond_index} + 1)]}, 'Data_Extraction_END');
    }
}
###################################################################################################
#   ���� ���o���ʕԋp ����                                                                        #
###################################################################################################
sub extraction_result {
    #-----------------------------------------------------------------------------------------#
    # ���� �F @_ = ED�R�}���h���o����                                                         #
    # ���� �F ED�R�}���h���o���ʂ��烆�[�U�X�N���v�g�֕ԋp������𐶐�                      #
    # �ԋp �F �ŏI���o����(���[�U�X�N���v�g�֕ԋp������)                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my @result_data = @_;                                                                     # ED�R�}���h���o����
    my @return_data = ();                                                                     # �ŏI���o����(���[�U�X�N���v�g�֕ԋp������)
    
    ################
    # ���o���ʐ��� #
    ################
    # ED�R�}���h���o���ʂ��烆�[�U�X�N���v�g�֕ԋp������𐶐�
    foreach my $result(@result_data) {
        # �ԋp�Ώۏ��̓��A�f�[�^�����݂̂𔲂��o��
        if ($result ne 'Data_Extraction_END' and ${$result}[3] ne 'DEL') {
            push(@return_data, "${$result}[4]");
        }
    }
    
    ####################
    # �ŏI���o���ʕԋp #
    ####################
    return @return_data;
}
###################################################################################################
#   ���� ���o�����u���� ����                                                                      #
###################################################################################################
sub change_extraction_cond {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���o�Ώۃf�[�^���                                                      #
    # ���� �F ��^���o�����̒u����                                                            #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $line_data) = @_;                                                               # �I�u�W�F�N�g�A���o�Ώۃf�[�^���
    my ($index_org, $seek_byte, $index_now, $out_kbn, $in_line) = @{$line_data};              # �I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A�o�͋敪�A���o�Ώۃf�[�^
    my $cond_index   = $obj->{cond_index};                                                    # �����ʒu
    my $cond_data    = \@{${$obj->{cond_data}}[$cond_index]};                                 # (�����ʒu��)���o����
    my $pipe_data    = \@{${$obj->{pipe_data}}[$cond_index]};                                 # (�����ʒu��)����pipe���
    my $cond_buf_max = ${$obj->{cond_buf_max}}[$cond_index];                                  # (�����ʒu��)��^�w��ő�o�b�t�@��
    my $line_end     = 0;                                                                     # �ŏI�s�ԍ�
    
    ################
    # �ŏI�s������ #
    ################
    # ���o�����ɍŏI�s�w��("end")�����邩�`�F�b�N
    if ((grep {${$_}[0] eq 'L' and (${$_}[2] =~ /end/ or ${$_}[3] =~ /end/)}@{$cond_data}) > 0) {
        #===============#
        # "end"�w�肠�� #
        #===============#
        # ����pipe����EOF��񂪑��݂��邩�`�F�b�N���A�ŏI�s�ԍ���ݒ�
        if (($#{$pipe_data} == $cond_buf_max and ${$pipe_data}[$cond_buf_max] eq 'Data_Extraction_END') or
            ($#{$pipe_data} >= 0 and $#{$pipe_data} < $cond_buf_max and ${$pipe_data}[$#{$pipe_data}] eq 'Data_Extraction_END')) {
            my $add_cnt = 0;
            for (my $index=0 ; $index <= $#{$pipe_data}; $index++) {
                # index�ʒu��EOF���`�F�b�N
                if (${$pipe_data}[$index] ne 'Data_Extraction_END') {
                    #------------#
                    # �ʏ�f�[�^ #
                    #------------#
                    # �㑱�f�[�^�����J�E���gUP
                    $add_cnt++;
                } else {
                    #-----#
                    # EOF #
                    #-----#
                    if ($index == 0) {
                        #���������������������#
                        # �����R�[�h���オEOF #
                        #���������������������#
                        # ���ݍs���ŏI�s�ԍ��ɐݒ�
                        $line_end = $index_now;
                    } else {
                        #��������������������������#
                        # �����R�[�h��Ƀf�[�^���� #
                        #��������������������������#
                        # �ŏI�s�ԍ����Z�o
                        $line_end = $index_now + $add_cnt;
                    }
                    last;
                }
            }
        }
    }
    
    #######################################
    # �ŏI�s�w��("end")���s�ԍ��w��ɕϊ� #
    #######################################
    # �ŏI�s�ԍ����ݒ�ł����ꍇ�A���o����("end")��������
    if ($line_end > 0) {
        # �J�n������ϊ�
        &get_cond_l_s($line_end, grep{${$_}[0] eq 'L' and ${$_}[2] =~ /end/}@{$cond_data});
        # �I��������ϊ�
        &get_cond_l_e($line_end, grep{${$_}[0] eq 'L' and ${$_}[3] =~ /end/}@{$cond_data});
    }
    
    ##################################
    # ���K�\���w����s�ԍ��w��ɕϊ� #
    ##################################
    # �J�n������ϊ��iget_cond_lr_s���Ŋ����ł��Ȃ��ꍇ�A���o�敪��"r"��ݒ�j
    if ((grep{${$_}[0] eq 'LR'}@{$cond_data}) > 0) {
        push(@{$cond_data}, &get_cond_lr_s($obj, $index_now, "$line_end", "$in_line", grep{${$_}[0] eq 'LR'}@{$cond_data}));
    }
    # �I��������ϊ�
    if ((grep{${$_}[0] eq 'r' and "$in_line" =~ /${$_}[3]/}@{$cond_data}) > 0) {
        &get_cond_lr_e($index_now, grep{${$_}[0] eq 'r' and "$in_line" =~ /${$_}[3]/}@{$cond_data});
    }
}
###################################################################################################
#   ���� ED�R�}���h���o���� ����                                                                  #
###################################################################################################
sub check_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���o�Ώۃf�[�^���                                                      #
    # ���� �F ��^���o�i�s�E��E�u���b�N���o�j�A���[�U�[���o�i���[�U�[�֐��ďo���j            #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $line_data) = @_;                                                               # �I�u�W�F�N�g�A���o�Ώۃf�[�^���
    my ($index_org, $seek_byte, $index_now, $out_kbn, $in_line) = @{$line_data};              # �I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A�o�͋敪�A���o�Ώۃf�[�^
    my $cond_index = $obj->{cond_index};                                                      # �����ʒu
    my $cond_data  = \@{${$obj->{cond_data}}[$cond_index]};                                   # (�����ʒu��)���o����
    my $buff_data  = \@{${$obj->{buff_data}}[$cond_index]};                                   # (�����ʒu��)�o�b�t�@���
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};                             # (�����ʒu��)�o��pipe���
    my $out_index  = \${$obj->{out_index}}[$cond_index];                                      # (�����ʒu��)�o�͌���
    
    ################
    # �o�b�t�@�o�^ #
    ################
    # ���[�U�w��ő�o�b�t�@���ȏ�ɂȂ����ꍇ�A�o�b�t�@����shift���ČÂ��f�[�^���폜
    if ($#{$buff_data} >= $obj->{user_buf_max}) {shift(@{$buff_data})}
    # ���o�Ώۃf�[�^�����o�b�t�@���̍Ō�ɓo�^
    push(@{$buff_data}, $line_data);
    
    ##################################
    # ���[�U�֐��o�͍Ϗ��̃`�F�b�N #
    ##################################
    if ($#{${$obj->{mid_data}}[$obj->{cond_index}]} >= 0) {
        # ���[�U�֐��ɂ���č폜�ς��`�F�b�N
        if (&check_mid_data($obj, $index_now)) {return ()}
        # ���[�U�֐��ɂ���Ēǉ��E�X�V�ς��`�F�b�N
        if (&put_mid_data($obj, $index_now)) {return ()}
    }
    
    my @in_line_col     = &get_col_data("$in_line");
    my $in_col_su       = $#in_line_col + 1;
    my $extraction_data = ('0' x $in_col_su);
    ##############
    # ���[�U���o #
    ##############
    if ((grep{${$_}[0] eq 'USER'}@{$cond_data}) > 0) {
        $extraction_data = "$extraction_data" |
                           &get_cond_user($obj, "$in_line", grep{${$_}[0] eq 'USER'}@{$cond_data});
    }
    # ���[�U���o���ʂ��O�̏ꍇ�A���[�U�֐��Œ��ڍX�V���Ă��Ȃ����`�F�b�N
    if ($extraction_data == 0) {
        # ���[�U�o�͗L���`�F�b�N
        #   ���[�U�o�͂���A����
        #   �ŏI�o��pipe���̓��͍s�ԍ������ݍs�A����
        #   �ŏI�o��pipe���̏o�͋敪��"USER"����"DEL"
        if ($obj->{user_out_kbn} ne '' and $#{$out_data} >= 0 and
            ${${$out_data}[$#{$out_data}]}[0] eq $index_org and
           (${${$out_data}[$#{$out_data}]}[3] eq 'USER' or ${${$out_data}[$#{$out_data}]}[3] eq 'DEL')) {
            #----------------------------#
            # ���[�U�ɂ���Č��ݍs���o�� #
            #----------------------------#
            # �o�͂��ꂽ��񂪍폜�w�����`�F�b�N
            if (${${$out_data}[$#{$out_data}]}[3] eq 'DEL') {
                #����������#
                # �폜�w�� #
                #����������#
                # �o��pipe���̍Ō�(�폜�w���f�[�^)���폜
                pop(@{$out_data});
            }
            # �ďo�����֖߂�
            return ();
        }
        # ��sED�R�}���h���o�Ń��[�U�o�͂��ꂽ�f�[�^���`�F�b�N
        if ($out_kbn eq 'USER') {
            #------------#
            # ���[�U�o�� #
            #------------#
            # �o�͌������J�E���gUP���A���o�Ώۃf�[�^�����o��pipe���̍Ō�ɓo�^
            ${$out_index}++;
            push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", 'USER', "$in_line"]);
            # �ďo�����֖߂�
            return ();
        }
    }
    
    if ("$extraction_data" =~ /^1/) {
        ######################
        # ���[�U���o���ʓo�^ #
        ######################
        my $out_line = &get_out_line("$in_line", \@in_line_col, "$extraction_data");
        # �o�̓J�E���^���J�E���gUP
        ${$out_index}++;
        # ���o���ʂ��o��pipe���ɓo�^
        push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", "$out_kbn", "$out_line"]);
    } else {
        ####################################
        # ��^���o(�s���o�A�s���o�{�񒊏o) #
        ####################################
        my @cond_data_lc = (grep{(${$_}[0] eq 'L' and ((${$_}[1] eq '' and ${$_}[2] !~ /end/ and ${$_}[2] <= $index_now and (${$_}[3] =~ /end/ or $index_now <= ${$_}[3]))
                                                    or (${$_}[1] ne '' and (${$_}[2] =~ /end/ or $index_now < ${$_}[2] or (${$_}[3] !~ /end/ and ${$_}[3] < $index_now))))
                              or (${$_}[0] eq 'r' and ((${$_}[1] eq '' and ${$_}[2] <= $index_now)
                                                    or (${$_}[1] ne '' and $index_now < ${$_}[2])))
                              or (${$_}[0] eq 'LR' and ${$_}[1] ne '' and ${$_}[8] eq '1' and ${$_}[9] <= $index_now))}@{$cond_data});
        if ($#cond_data_lc >= 0) {
            # �s�ԍ��w��ɂ��s���o("L"���s�ԍ��w��A���͍s�ԍ��w��֕ϊ��������K�\���w��(��"LR"))
            # �E�m�蒊�o�A���i�J�n�s�ԍ������ݍs���I���s�ԍ��A���͏I���s�ԍ���"end"�j
            # �E�ے蒊�o�A���i�J�n�s�ԍ���"end"�A���͌��ݍs���I���s�ԍ��A���́i�I���s�ԍ���"end"�A���I���s�ԍ������ݍs�j�j
            # ���K�\���ɂ��s���o("r"���J�n�����̂ݍs�ԍ��w��֕ϊ����Ă���(��"LR"))
            # �E�m�蒊�o�A���J�n�s�ԍ������ݍs
            # �E�ے蒊�o�A�����ݍs���J�n�s�ԍ�
            # ���K�\���ɂ��s���o("LR"�����K�\���w�肪�s�ԍ��w��֕ϊ�����Ă��Ȃ�)
            # �E�ے蒊�o�A�����o���������o
            $extraction_data = "$extraction_data" |
                               &get_cond_lc("$in_line", $in_col_su, @cond_data_lc);
            
            if ("$extraction_data" =~ /^1/) {
                ########################
                # ��^���o���ʓo�^(�s) #
                ########################
                my $out_line = &get_out_line("$in_line", \@in_line_col, "$extraction_data");
                # �o�̓J�E���^���J�E���gUP
                ${$out_index}++;
                # ���o���ʂ��o��pipe���ɓo�^
                push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", "$out_kbn", "$out_line"]);
                # �s�v�ɂȂ������o�������폜
                my @cond_data_new = ();
                foreach my $cut_cond(@{$cond_data}) {
                    if (${$cut_cond}[0] ne 'L' or (${$cut_cond}[0] eq 'L' and ((${$cut_cond}[1] eq '' and (${$cut_cond}[2] =~ /end/ or ${$cut_cond}[3] =~ /end/ or ${$cut_cond}[3] > $index_now))
                                                                             or ${$cut_cond}[1] ne '' ))) {
                        push(@cond_data_new, \@{$cut_cond});
                    }
                }
                @{$cond_data} = @cond_data_new;
                if ($#{$cond_data} < 0) {
                    push(@{$out_data}, 'Data_Extraction_END');
                }
                return ();
            }
        }
        
        ####################
        # ��^���o(�񒊏o) #
        ####################
        my @cond_data_temp = (grep{${$_}[0] =~ /C/}@{$cond_data});
        if ($#cond_data_temp >= 0) {
            # ��ԍ��w��ɂ��񒊏o("C")
            $extraction_data = "$extraction_data" |
                               &get_cond_c($in_col_su, grep{${$_}[0] eq 'C'}@{$cond_data});
            # ���K�\���ɂ��񒊏o("CR")
            $extraction_data = "$extraction_data" |
                               &get_cond_cr("$in_line", $in_col_su, grep{${$_}[0] eq 'CR'}@{$cond_data});
        }
        
        ########################
        # ��^���o���ʓo�^(��) #
        ########################
        if ($extraction_data > 0) {
            my $out_line = &get_out_line("$in_line", \@in_line_col, "$extraction_data");
            # �o�̓J�E���^���J�E���gUP
            ${$out_index}++;
            # ���o���ʂ��o��pipe���ɓo�^
            push(@{$out_data}, ["$index_org", "$seek_byte", "${$out_index}", "$out_kbn", "$out_line"]);
        }
    }
}
###################################################################################################
#   ���� ���[�U��s�o�͏��`�F�b�N ����                                                          #
###################################################################################################
sub check_mid_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���͍s�ԍ�                                                              #
    # ���� �F ���͍s�ԍ��ƈ�v���郆�[�U��s�o�͏��(�폜)�����邩�`�F�b�N                    #
    # �ԋp �F �`�F�b�N�t���O�i�P���폜�Ώۂ���A�O���폜�ΏۂȂ��j                            #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $index_now) = @_;                                                               # �I�u�W�F�N�g�A���͍s�ԍ�
    my $mid_data          = \@{${$obj->{mid_data}}[$obj->{cond_index}]};                      # (�����ʒu��)���[�U��s�o�͏��
    
    ##############################
    # ���[�U��s�o�͏��`�F�b�N #
    ##############################
    for (my $index=0 ; $index <= $#{$mid_data}; $index++) {
        # ���͍s�ԍ�����v����f�[�^���폜���(�o�͋敪��"DEL")���`�F�b�N
        if (${${$mid_data}[$index]}[2] == $index_now and ${${$mid_data}[$index]}[3] eq 'DEL') {
            #==========#
            # �폜�Ώ� #
            #==========#
            # �u�폜�Ώۂ���v��ԋp
            return 1;
        }
    }
    # �u�폜�ΏۂȂ��v��ԋp
    return 0;
}
###################################################################################################
#   ���� ���[�U��s�o�͏��o�^ ����                                                              #
###################################################################################################
sub put_mid_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���͍s�ԍ�                                                              #
    # ���� �F ���͍s�ԍ��ƈ�v���郆�[�U��s�o�͏����o��pipe���֓o�^                      #
    # �ԋp �F �o�̓t���O�i�P������A�O���Ȃ��j                                                #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $index_now) = @_;                                                               # �I�u�W�F�N�g�A���͍s�ԍ�
    my $mid_data  = \@{${$obj->{mid_data}}[$obj->{cond_index}]};                              # (�����ʒu��)���[�U��s�o�͏��
    my $out_data  = \@{${$obj->{pipe_data}}[($obj->{cond_index} + 1)]};                       # (�����ʒu��)�o��pipe���
    my $out_index = \${$obj->{out_index}}[$obj->{cond_index}];                                # (�����ʒu��)�o�͌���
    my $out_flg   = 0;                                                                        # �o�̓t���O
    
    ##############################
    # ���[�U��s�o�͏��`�F�b�N #
    ##############################
    # �J�����g�s�ɑ΂��郆�[�U��s�o�͏�񂪂��邩����
    for (my $index=0 ; $index <= $#{$mid_data}; $index++) {
        # ���͍s�ԍ�����v���邩�`�F�b�N
        if ($index_now == ${${$mid_data}[$index]}[2]) {
            #==============================#
            # �s�ԍ�����v(�J�����g�s����) #
            #==============================#
            # �o�͌������J�E���gUP
            ${$out_index}++;
            # ���[�U��s�o�͏����o��pipe���֓o�^
            push(@{$out_data}, ["${${$mid_data}[$index]}[0]", "${${$mid_data}[$index]}[1]", "${$out_index}", "${${$mid_data}[$index]}[3]", "${${$mid_data}[$index]}[4]"]);
            # �u���[�U��s�o�͂���v���o�̓t���O�֐ݒ�
            $out_flg = 1;
            # �u���[�U�o�͂���v�����[�U�o�͋敪�֐ݒ�
            $obj->{user_out_kbn} = 'output';
        }
    }
    
    ##################
    # �o�̓t���O�ԋp #
    ##################
    return $out_flg;
}
###################################################################################################
#   ���� ���o�f�[�^���擾 ����                                                                    #
###################################################################################################
sub get_out_line {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �s�f�[�^                                                                #
    #      �F $_[1] = �z�񉻂����s�f�[�^                                                      #
    #      �F $_[2] = ���o�Ώۋ敪                                                            #
    # ���� �F ���o�Ώۋ敪���璊�o�f�[�^���擾                                                #
    # �ԋp �F ���o�f�[�^                                                                      #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($line, $col_data, $extraction_data) = @_;                                             # �s�f�[�^�A�z�񉻂����s�f�[�^�A���o�Ώۋ敪
    ##################
    # ���o�f�[�^�擾 #
    ##################
    # �s���o���񒊏o���`�F�b�N
    if ("$extraction_data" =~ /^1/) {
        #========#
        # �s���o #
        #========#
        # �s�f�[�^�����̂܂ܒ��o�f�[�^�Ƃ���
        return "$line";
    } else {
        #========#
        # �񒊏o #
        #========#
        # "1"(���o�Ώ�)�ɂȂ��Ă����̂ݒ��o�f�[�^�Ƃ���
        unshift @{$col_data}, '';
        my $out_data = '';
        for (my $index=1; $index <= $#{$col_data}; $index++) {
            if ((substr $extraction_data, $index, 1) eq '1') {
                $out_data .= "${$col_data}[$index] ";
            }
        }
        chop $out_data;
        return $out_data;
    }
}
###################################################################################################
#   ���� ���̓t�@�C���n�o�d�m ����                                                                #
###################################################################################################
sub in_file_open {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓t�@�C����                                                          #
    # ���� �F ���̓t�@�C���̃t�@�C���n�o�d�m                                                  #
    #-----------------------------------------------------------------------------------------#
    if (! open (EXTRACTION_FILE, "< $_[0]")) {
        # ���̓t�@�C��OPEN�G���[
        print STDERR "Input File($_[0]) cannot Open\n";
        exit 99;
    }
    #flock(EXTRACTION_FILE, 1);
}
###################################################################################################
#   ���� ���̓t�@�C���b�k�n�r�d ����                                                              #
###################################################################################################
sub in_file_close {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = ���̓t�@�C����                                                          #
    # ���� �F ���̓t�@�C���̃t�@�C���b�k�n�r�d                                                #
    #-----------------------------------------------------------------------------------------#
    if (! close (EXTRACTION_FILE)) {
        # ���̓t�@�C��CLOSE�G���[
        print STDERR "Input File($_[0]) cannot Close\n";
        exit 99;
    }
}
###################################################################################################
#   ���� �������s�ԍ��擾 ����                                                                    #
###################################################################################################
sub get_line_num {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F �������̍s�ԍ����擾                                                            #
    # �ԋp �F �������̍s�ԍ�                                                                  #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj       = shift;                                                                    # �I�u�W�F�N�g
    my $in_data   = \@{${$obj->{pipe_data}}[$obj->{cond_index}]};                             # (�����ʒu��)����pipe���
    my $buff_data = \@{${$obj->{buff_data}}[$obj->{cond_index}]};                             # (�����ʒu��)�o�b�t�@���
    
    # seek�敪���`�F�b�N���Aseek�ʒu�̍s�ԍ����擾�E�ԋp
    if ($obj->{seek_kbn} eq 'buff') {
        #======================#
        # �o�b�t�@��񂩂�擾 #
        #======================#
        return ${${$buff_data}[$obj->{seek_index}]}[2];
    } elsif ($obj->{seek_kbn} eq 'input') {
        #======================#
        # ����pipe��񂩂�擾 #
        #======================#
        return ${${$in_data}[$obj->{seek_index}]}[2];
    } else {
        #========================#
        # �I���W�i����񂩂�擾 #
        #========================#
        return ${$obj->{seek_num}}[2];
    }
}
###################################################################################################
#   ���� seek�s�ԍ��`�F�b�N ����                                                                  #
###################################################################################################
sub check_seek_num {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = seek�s�ԍ�                                                              #
    # ���� �F �s�ԍ��̋L�q�`�F�b�N                                                            #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $seek_no) = @_;                                                                 # �I�u�W�F�N�g�Aseek�s�ԍ�
    my $buff_data       = \@{${$obj->{buff_data}}[$obj->{cond_index}]};                       # (�����ʒu��)�o�b�t�@���
    
    ######################
    # seek�s�ԍ��`�F�b�N #
    ######################
    # �O���傫���������`�F�b�N
    if ($seek_no !~ /^\d+$/ or $seek_no <= 0) {
        #==============================#
        # �����ȊO�A�܂��͂O�ȉ��̐��� #
        #==============================#
        # seek�s�ԍ��G���[
        print STDERR "Seek Line Number Error ($seek_no)\n";
        exit 99;
    }
    
    ##############################
    # seek�\�ȍs�ԍ����`�F�b�N #
    ##############################
    # ���[�U�w��ő�o�b�t�@�����z���Ă��Ȃ����`�F�b�N
    if ((${${$buff_data}[$#{$buff_data}]}[2] < $seek_no and (${${$buff_data}[$#{$buff_data}]}[2] + $obj->{user_buf_max}) < $seek_no) or
        (${${$buff_data}[$#{$buff_data}]}[2] > $seek_no and (${${$buff_data}[$#{$buff_data}]}[2] - $obj->{user_buf_max}) > $seek_no)) {
        #======================================#
        # ���[�U�w��ő�o�b�t�@�����z���Ă��� #
        #======================================#
        # seek�͈̓G���[
        print STDERR "Seek Buffer Range Error ($seek_no)\n";
        exit 99;
    }
}
###################################################################################################
#   ���� �f�[�^�擾�敪�`�F�b�N ����                                                              #
###################################################################################################
sub check_data_acquisition_division {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �f�[�^�擾�敪                                                          #
    # ���� �F �f�[�^�擾�敪�̋L�q�`�F�b�N                                                    #
    #-----------------------------------------------------------------------------------------#
    if ($_[0] ne 'org' and $_[0] ne 'now') {
        print STDERR "Data Acquisition division Error ($_[0])\n";
        exit 99;
    }
}
###################################################################################################
#   ���� �o�b�t�@�G���[ ����                                                                      #
###################################################################################################
sub error_buffers {
    # �o�b�t�@�ɊY���f�[�^����
    print STDERR "Buffers does not have Line Number Pertinence Data (line($_[0])-\>seek($_[1]))\n";
    exit 99;
}
###################################################################################################
#   ���� ���o�Ώۃf�[�^�擾�ʒu�w�� ����                                                          #
###################################################################################################
sub seek_line {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = seek�s�ԍ�                                                              #
    # ���� �F �s�ԍ��`�F�b�N�A���o�Ώۃf�[�^�̓Ǎ��ވʒu���w��s�ֈړ�                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $seek_no) = @_;                                                                 # �I�u�W�F�N�g�Aseek�s�ԍ�
    my $cond_index = $obj->{cond_index};                                                      # �����ʒu
    my $in_data    = \@{${$obj->{pipe_data}}[$cond_index]};                                   # (�����ʒu��)����pipe���
    my $buff_data  = \@{${$obj->{buff_data}}[$cond_index]};                                   # (�����ʒu��)�o�b�t�@���
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};                             # (�����ʒu��)�o��pipe���
    
    ######################
    # seek�s�ԍ��`�F�b�N #
    ######################
    &check_seek_num($obj, "$seek_no");
    
    ########################
    # seek��f�[�^�ʒu�擾 #
    ########################
    # ���[�U�o�͍ς̏ꍇ�A"seek"(���[�U�o�͌��seek)�����[�U�o�͋敪�ɐݒ�
    if ($obj->{user_out_kbn} ne '') {
        $obj->{user_out_kbn} = 'seek';
    }
    # seek�s�ԍ����`�F�b�N���Aseek�Ώې��U�蕪����
    if ($seek_no <= ${${$buff_data}[$#{$buff_data}]}[2]) {
        #==================#
        # seek�悪�����ύs #
        #==================#
        # �o�b�t�@��������
        for (my $index=0; $index <= $#{$buff_data}; $index++) {
            # ���ݍs��seek�s�ԍ��̃f�[�^���`�F�b�N
            if ($seek_no == ${${$buff_data}[$index]}[2]) {
                #--------------------------#
                # seek�s�ԍ��̃f�[�^������ #
                #--------------------------#
                # ���͋敪��"�t�@�C��"�̏ꍇ�A���o�������R�[�hbyte�ʒu�ֈړ�
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${${$buff_data}[$index]}[1]), 0 or "$!($obj->{in_name})";
                }
                # ��seek���̐ݒ聄
                $obj->{seek_kbn}          = 'buff';                                           # seek�敪���o�b�t�@���("buff")
                @{$obj->{seek_num}}[0..2] = @{${$buff_data}[$index]};                         # seek�s��񁩃o�b�t�@���(�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ�)
                $obj->{seek_index}        = $index;                                           # seek�ʒu�����oindex
                # ��get���̐ݒ聄
                $obj->{get_kbn}           = $obj->{seek_kbn};                                 # get�敪
                @{$obj->{get_num}}        = @{$obj->{seek_num}};                              # get�s���
                $obj->{get_index}         = $obj->{seek_index};                               # get�ʒu
                # ���ďo�����֕��A��
                return 0;
            }
        }
        # seek�G���[
        &error_buffers(${${$buff_data}[$#{$buff_data}]}[2],$seek_no);
    } else {
        #================#
        # seek�悪�㑱�s #
        #================#
        # ����ڂ�ED�R�}���h���o�������ʒu���`�F�b�N���A������U�蕪����
        if ($cond_index > 0) {
            #--------------------------------#
            # �㑱(�Q�ڈȍ~)ED�R�}���h���o #
            #--------------------------------#
            # �ő匟����(for_max)��ݒ�
            my $for_max = $#{$in_data};                                                       # ����pipe��񐔂�ݒ�
            if (${$in_data}[$#{$in_data}] ne 'Data_Extraction_END') {
                $for_max = $obj->{user_buf_max};                                              # ���[�U�w��ő�o�b�t�@����ݒ�
            }
            # ����pipe���(index=0�`�ő匟����)������
            for (my $index=0; $index <= $for_max; $index++) {
                # ���ݍs��seek�s�ԍ��̃f�[�^���`�F�b�N
                if ($seek_no == ${${$in_data}[$index]}[2]) {
                    #��������������������������#
                    # seek�s�ԍ��̃f�[�^������ #
                    #��������������������������#
                    # ���͋敪��"�t�@�C��"�̏ꍇ�A���o�������R�[�hbyte�ʒu�ֈړ�
                    if ($obj->{in_kbn} ne '') {
                        seek EXTRACTION_FILE, (${${$in_data}[$index]}[1]), 0 or "$!($obj->{in_name})";
                    }
                    # ��seek���̐ݒ聄
                    $obj->{seek_kbn}          = 'input';                                      # seek�敪������pipe���("input")
                    @{$obj->{seek_num}}[0..2] = @{${$in_data}[$index]};                       # seek�s��񁩓���pipe���(�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ�)
                    $obj->{seek_index}        = $index;                                       # seek�ʒu�����oindex
                    # ��get���̐ݒ聄
                    $obj->{get_kbn}           = $obj->{seek_kbn};                             # get�敪
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};                          # get�s���
                    $obj->{get_index}         = $obj->{seek_index};                           # get�ʒu
                    # ���ďo�����֕��A��
                    return 0;
                }
            }
            # seek�G���[
            &error_buffers(${${$buff_data}[$#{$buff_data}]}[2],$seek_no);
        } else {
            #--------------------#
            # ����ED�R�}���h���o #
            #--------------------#
            # ���͋敪��"�t�@�C��"�̏ꍇ�A�ŏI�o�b�t�@���̃��R�[�hbyte�ʒu�ֈړ�
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${${$buff_data}[$#{$buff_data}]}[1]), 0 or "$!($obj->{in_name})";
            }
            # �ŏI�o�b�t�@���(���͍s�ԍ�)���`�F�b�N�s�ԍ��֐ݒ�
            my $check_no = ${${$buff_data}[$#{$buff_data}]}[2];
            # �I���W�i���s�f�[�^���擾
            my $line = &get_line_data($obj, $check_no);
            # EOF�ɂȂ�܂ŁA�I���W�i����������
            while ("$line" ne 'Data_Extraction_END') {
                # �`�F�b�N�s�ԍ����J�E���gUP
                $check_no++;
                # ���ݍs��seek�s�ԍ��̃f�[�^���`�F�b�N
                if ($seek_no == $check_no) {
                    #��������������������������#
                    # seek�s�ԍ��̃f�[�^�����o #
                    #��������������������������#
                    # ��seek���̐ݒ聄
                    $obj->{seek_kbn}          = 'org';                                        # seek�敪���I���W�i�����("org")
                    @{$obj->{seek_num}}[0..2] = ($check_no, (tell EXTRACTION_FILE), $seek_no);# seek�s��񁩃I���W�i�����(�`�F�b�N�s�ԍ��A���R�[�hbyte�ʒu�Aseek�s�ԍ�)
                    $obj->{seek_index}        = 0;                                            # seek�ʒu���O
                    # ��get���̐ݒ聄
                    $obj->{get_kbn}           = $obj->{seek_kbn};                             # get�敪
                    @{$obj->{get_num}}        = @{$obj->{seek_num}};                          # get�s���
                    $obj->{get_index}         = $obj->{seek_index};                           # get�ʒu
                    # ���ďo�����֕��A��
                    return 0;
                }
                # �I���W�i���s�f�[�^���擾
                $line = &get_line_data($obj, $check_no);
            }
            # seek�G���[
            &error_buffers(${${$buff_data}[$#{$buff_data}]}[2],$seek_no);
        }
    }
}
###################################################################################################
#   ���� ���o�Ώۃf�[�^�擾 ����                                                                  #
###################################################################################################
sub get_line {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �f�[�^�擾�敪�iorg�F�I���W�i���^now�F���o���ʁj                        #
    # ���� �F �f�[�^�擾�敪�`�F�b�N�A���o�Ώۃf�[�^�̎擾                                    #
    # �ԋp �F ���o�Ώۃf�[�^                                                                  #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $data_kbn) = @_;                                                                # �I�u�W�F�N�g�A�f�[�^�擾�敪
    my $line        = '';                                                                     # ���o�Ώۃf�[�^
    my $cond_index  = $obj->{cond_index};                                                     # �����ʒu
    my $in_data     = \@{${$obj->{pipe_data}}[$cond_index]};                                  # (�����ʒu��)����pipe���
    my $buff_data   = \@{${$obj->{buff_data}}[$cond_index]};                                  # (�����ʒu��)�o�b�t�@���
    
    ##########################
    # �f�[�^�擾�敪�`�F�b�N #
    ##########################
    &check_data_acquisition_division("$data_kbn");
    
    ######################
    # ���o�Ώۃf�[�^�擾 #
    ######################
    # �擾�敪���`�F�b�N���A������U�蕪����
    if ($data_kbn eq 'org' or $obj->{seek_kbn} eq 'org') {
        #==========================#
        # �I���W�i���f�[�^����擾 #
        #==========================#
        # seek�敪��seek�s���(�擾�敪)�֐ݒ�
        ${$obj->{seek_num}}[3] = $obj->{seek_kbn};
        # seek�ʒu��␳���ׂ����`�F�b�N
        # �E�O��擾���I���W�i�����ȊO�A���㑱(�Q��ڈȍ~��)ED�R�}���h���o�A���f�[�^�擾�敪�̎w���ɂ��I���W�i�����擾
        if (${$obj->{get_num}}[3] ne 'org' and
            $obj->{seek_kbn} ne 'org' and
            ${$obj->{get_num}}[2] ne ${$obj->{seek_num}}[2]) {
            # ���͋敪��"�t�@�C��"�̏ꍇ�Aseek�s���̃��R�[�hbyte�ʒu�ֈړ�
            if ($obj->{in_kbn} ne '') {
                seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
                my $line2 = &get_line_data($obj, ${$obj->{seek_num}}[0]);
                # get_line_data�Ŏ��ֈړ����Ă��܂��ׁAseek�s���̓��͍s�ԍ���߂�
                ${$_[0]->{seek_num}}[2]--;
            }
        }
        # ���o�Ώۃf�[�^���擾
        if ($_[0]->{in_kbn} eq '') {
            $line = &get_line_data($obj, (${$obj->{seek_num}}[0] - 1));
        } else {
            $line = &get_line_data($obj);
        }
        
        # ��get���̐ݒ聄
        $obj->{get_kbn}    = $obj->{seek_kbn};                                                # get�敪
        @{$obj->{get_num}} = @{$obj->{seek_num}};                                             # get�s���
        $obj->{get_index}  = $obj->{seek_index};                                              # get�ʒu
        # ��seek���̐ݒ聄
        # seek�s���(�I���W�i���s�ԍ�)���J�E���gUP
        ${$obj->{seek_num}}[0]++;
        # seek�敪���u�I���W�i����񂩂�擾("org")�v�ȊO�̏ꍇ�Aseek�s����ݒ�
        if ($obj->{seek_kbn} eq 'buff' or $obj->{seek_kbn} eq 'input') {
            # seek�ʒu���J�E���gUP���ׂ����`�F�b�N
            # �Eget�s���(�擾�敪)���u�I���W�i������擾("org")�v�A����seek�s���(�擾�敪)���u�I���W�i������擾("org")�v
            # �Eseek�敪���u�o�b�t�@���("buff")�v�A����seek��I���W�i���s�ԍ���seek�s���(�I���W�i���s�ԍ�)
            # �Eseek�敪���u����pipe���("input")�v�A����seek��I���W�i���s�ԍ���seek�s���(�I���W�i���s�ԍ�)
            if ((${$obj->{get_num}}[3] eq 'org'  and ${$obj->{seek_num}}[3] eq 'org') or
                ($obj->{seek_kbn} eq 'buff'  and ${${$buff_data}[$obj->{seek_index}]}[0] < ${$obj->{seek_num}}[0]) or
                ($obj->{seek_kbn} eq 'input' and ${${$in_data}[$obj->{seek_index}]}[0] < ${$obj->{seek_num}}[0])) {
                # seek�ʒu���J�E���gUP
                $obj->{seek_index}++;
            }
            # seek�敪���u�o�b�t�@��񂩂�擾("buff")�v�A����seek�ʒu���o�b�t�@��񐔂𒴂��Ă���ꍇ�Aseek�敪�Eseek�ʒu��ݒ�
            if ($obj->{seek_kbn} eq 'buff' and $#{$buff_data} < $obj->{seek_index}) {
                # ���o�ʒu���`�F�b�N���A���̎擾�������߂�
                if ($cond_index > 0) {
                    #----------------------------#
                    # ����͓���pipe��񂩂�擾 #
                    #----------------------------#
                    $obj->{seek_kbn}   = 'input';                                             # seek�敪������pipe���("input")
                    $obj->{seek_index} = 0;                                                   # seek�ʒu���O
                } else {
                    #------------------------------#
                    # ����̓I���W�i����񂩂�擾 #
                    #------------------------------#
                    $obj->{seek_kbn}   = 'org';                                               # seek�敪���I���W�i�����("org")
                    $obj->{seek_index} = 0;                                                   # seek�ʒu���O
                }
            }
        }
        # get�s���̎擾�敪�Ɂu�I���W�i������擾("org")�v��ݒ�
        ${$obj->{get_num}}[3] = 'org';
    } else {
        #================================#
        # ��sED�R�}���h���o���ʂ���擾 #
        #================================#
        # seek�敪���`�F�b�N���A�f�[�^�擾���U�蕪����
        if ($obj->{seek_kbn} eq 'buff') {
            #----------------------#
            # �o�b�t�@��񂩂�擾 #
            #----------------------#
            ${$obj->{seek_num}}[0] = ${${$buff_data}[$obj->{seek_index}]}[0];                 # �I���W�i���s�ԍ�
            ${$obj->{seek_num}}[1] = ${${$buff_data}[$obj->{seek_index}]}[1];                 # ���R�[�hbyte�ʒu
            $line                  = ${${$buff_data}[$obj->{seek_index}]}[4];                 # ���o�Ώۃf�[�^
        } else {
            #----------------------#
            # ����pipe��񂩂�擾 #
            #----------------------#
            ${$obj->{seek_num}}[0] = ${${$in_data}[$obj->{seek_index}]}[0];                   # �I���W�i���s�ԍ�
            ${$obj->{seek_num}}[1] = ${${$in_data}[$obj->{seek_index}]}[1];                   # ���R�[�hbyte�ʒu
            $line                  = ${${$in_data}[$obj->{seek_index}]}[4];                   # ���o�Ώۃf�[�^
        }
        
        # ��get���̐ݒ聄
        $obj->{get_kbn}    = $obj->{seek_kbn};                                                # get�敪
        @{$obj->{get_num}} = @{$obj->{seek_num}};                                             # get�s���
        $obj->{get_index}  = $obj->{seek_index};                                              # get�ʒu
        # ��seek���̐ݒ聄
        # seek�ʒu���J�E���gUP
        $obj->{seek_index}++;
        # seek�敪�Eseek�ʒu���Đݒ肷��K�v�����邩�`�F�b�N
        # �Eseek�敪���u�o�b�t�@��񂩂�擾("buff")�v�A����seek�ʒu���o�b�t�@��񐔂𒴂��Ă���
        if ($obj->{seek_kbn} eq 'buff' and $#{$buff_data} < $obj->{seek_index}) {
            #----------------------------------#
            # seek�敪�Eseek�ʒu�̍Đݒ肪�K�v #
            #----------------------------------#
            # ���o�ʒu���`�F�b�N���A���̎擾�������߂�
            if ($cond_index > 0) {
                #����������������������������#
                # ����͓���pipe��񂩂�擾 #
                #����������������������������#
                $obj->{seek_kbn}   = 'input';                                                 # seek�敪������pipe���("input")
                $obj->{seek_index} = 0;                                                       # seek�ʒu���O
            } else {
                #������������������������������#
                # ����̓I���W�i����񂩂�擾 #
                #������������������������������#
                # ���͋敪��"�t�@�C��"�̏ꍇ�Aseek�s���̃��R�[�hbyte�ʒu�ֈړ�
                if ($obj->{in_kbn} ne '') {
                    seek EXTRACTION_FILE, (${$obj->{seek_num}}[1]), 0 or "$!($obj->{in_name})";
                    my $line2 = &get_line_data($obj, ${$obj->{seek_num}}[0]);
                }
                $obj->{seek_kbn}   = 'org';                                                   # seek�敪���I���W�i�����("org")
                $obj->{seek_index} = 0;                                                       # seek�ʒu���O
                # seek�s���(�I���W�i���s�ԍ�)���J�E���gUP
                ${$obj->{seek_num}}[0]++;
            }
        } else {
            # seek�s���(�I���W�i���s�ԍ�)���J�E���gUP
            ${$obj->{seek_num}}[0]++;
            # seek�s���(���͍s�ԍ�)���J�E���gUP
            ${$obj->{seek_num}}[2]++;
        }
    }
    return "$line";
}
###################################################################################################
#   ���� ���R�[�h���擾 ����                                                                    #
###################################################################################################
sub get_line_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = ���͍s�ԍ�                                                              #
    # �ԋp �F �擾���R�[�h���                                                                #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $line_index) = @_;                                                              # �I�u�W�F�N�g�A���͍s�ԍ�
    my $line = '';                                                                            # �擾���R�[�h���
    
    # ���͋敪���`�F�b�N���A�擾��𔻒f
    if ($obj->{in_kbn} eq '') {
        #==============#
        # �ϐ�����擾 #
        #==============#
        my $check = '^';
        for (my $index=1; $index <= $line_index; $index++) {
            $check .= '.*\n';
        }
        $check .= '(.*\n{0,1})';
        if ((eval($obj->{in_name})) =~ /$check/) {
            $line = $1;
        }
    } else {
        #==================#
        # �t�@�C������擾 #
        #==================#
        $line = <EXTRACTION_FILE>;
    }
    
    # �擾�f�[�^��EOF���`�F�b�N
    if ($line eq '') {
        #=====#
        # EOF #
        #=====#
        # EOF("Data_Extraction_END")���擾���R�[�h���֐ݒ�
        $line = 'Data_Extraction_END';
    } else {
        #============#
        # �f�[�^���� #
        #============#
        # �擾�f�[�^�̉��s�R�[�h���폜
        if ((substr $line, -1) eq "\n") {
            chop $line;
        }
    }
    # seek�s���(���͍s�ԍ�)���J�E���gUP
    ${$obj->{seek_num}}[2]++;
    
    # �擾���R�[�h����ԋp
    return "$line";
}
###################################################################################################
#   ���� ���o�敪������ ����                                                                      #
###################################################################################################
sub init_extraction_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �z�񉻂����s�f�[�^�̔z��                                              #
    # ���� �F ���o�敪���������i�z�񉻂����s�f�[�^�̔z�񐔕��j                                #
    # �ԋp �F �������������o�敪                                                              #
    #-----------------------------------------------------------------------------------------#
    my $extraction_data = '0' x ($_[0] + 1);
    return "$extraction_data";
}
###################################################################################################
#   ���� �s�f�[�^�z��ϊ� ����                                                                    #
###################################################################################################
sub get_col_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �s�f�[�^                                                                #
    # ���� �F �s�f�[�^����؂蕶���ŕ���                                                      #
    # �ԋp �F �z�񉻂����s�f�[�^                                                              #
    #-----------------------------------------------------------------------------------------#
    return (split /\s+\,*\s*|\,+\s*/, $_[0]);
}
###################################################################################################
#   ���� ���o�f�[�^�ǉ��E�X�V ����                                                                #
###################################################################################################
sub add_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #      �F $_[1] = �s�f�[�^                                                                #
    # ���� �F �s�f�[�^�𒊏o�f�[�^�̃J�����g�s�iseek���Ă���ꍇ�́A���̍s�j�ɒǉ��E�X�V      #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj, $out_line) = @_;                                                                # �I�u�W�F�N�g�A�s�f�[�^
    my $cond_index = $obj->{cond_index};                                                      # �����ʒu
    my $in_data    = \@{${$obj->{pipe_data}}[$cond_index]};                                   # (�����ʒu��)����pipe���
    my $buff_data  = \@{${$obj->{buff_data}}[$cond_index]};                                   # (�����ʒu��)�o�b�t�@���
    my $mid_data   = \@{${$obj->{mid_data}}[$cond_index]};                                    # (�����ʒu��)���[�U��s�o�͏��
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};                             # (�����ʒu��)�o��pipe���
    my $out_index  = \${$obj->{out_index}}[$cond_index];                                      # (�����ʒu��)�o�͌���
    
    # get�敪���`�F�b�N���A�o�͐�𔻒f
    if ($obj->{get_kbn} eq 'buff') {
        ######################
        # �o�b�t�@���֏o�� #
        ######################
        # �J�����g���ŏI�o�b�t�@���ʒu�������ꍇ�A�s�f�[�^���o�b�t�@���̍Ō�֒ǉ�
        if ($obj->{get_index} == $#{$buff_data}) {
            #================================#
            # �J�����g���ŏI�o�b�t�@���ʒu #
            #================================#
            # �o�b�t�@���̍Ō�ɍs�f�[�^��ǉ�
            ${$out_index}++;
            push(@{$out_data}, ["${${$buff_data}[$#{$buff_data}]}[0]", "${${$buff_data}[$#{$buff_data}]}[1]", "${$out_index}", 'USER', "$out_line"]);
            # ���[�U�o�͍�("output")�����[�U�o�͋敪�֐ݒ�
            $obj->{user_out_kbn} = 'output';
        } else {
            #====================#
            # �J�����g�������ύs #
            #====================#
            # �o��pipe��������
            for (my $index=$#{$out_data} ; $index >= 0 ; $index--) {
                # �I���W�i���s�ԍ����`�F�b�N���A�o�^�ʒu�����߂�
                if (${${$out_data}[$index]}[0] == ${$obj->{get_num}}[0]) {
                    #------------------------#
                    # �I���W�i���s�ԍ�����v #
                    #------------------------#
                    # �o�^���@(�ǉ��E�X�V)�̐U�蕪��
                    if ($obj->{user_out_kbn} ne 'output') {
                        #��������������#
                        # ���[�U���o�� #
                        #��������������#
                        # ��^���o���ʂ����[�U�w��f�[�^�ɒu������
                        ${${$out_data}[$index]}[3] = 'USER';                                  # �o�͋敪
                        ${${$out_data}[$index]}[4] = "$out_line";                             # ���o�Ώۃf�[�^
                    } elsif ($index == $#{$out_data}) {
                        #����������������������������������#
                        # �o�b�t�@���(�Ō�)�Ƀ��[�U�o�͍� #
                        #����������������������������������#
                        # �o��pipe���̍Ō�ɍs�f�[�^��ǉ�
                        ${$out_index}++;
                        push(@{$out_data}, ["${${$out_data}[$index]}[0]", "${${$out_data}[$index]}[1]", "${$out_index}", 'USER', "$out_line"]);
                    } else {
                        #����������������������������������#
                        # �o�b�t�@���(�r��)�Ƀ��[�U�o�͍� #
                        #����������������������������������#
                        # �o��pipe���̓r���ɍs�f�[�^��}��
                        ${$out_index}++;
                        splice(@{$out_data}, ($index + 1), 0, ["${${$out_data}[$index]}[0]", "${${$out_data}[$index]}[1]", "${$out_index}", 'USER', "$out_line"]);
                    }
                    # ���[�U�o�͍�("output")�����[�U�o�͋敪�֐ݒ�
                    $obj->{user_out_kbn} = 'output';
                    # �o��pipe���̌������I��
                    last;
                } elsif (${${$out_data}[$index]}[0] < ${$obj->{get_num}}[0]) {
                    #----------------------------------------------------------------------#
                    # �I���W�i���s�ԍ��𖢌��o�̂܂܏o��pipe���(�I���W�i���s�ԍ�)���߂��� #
                    #----------------------------------------------------------------------#
                    # �o��pipe���̓r���ɍs�f�[�^��}��
                    ${$out_index}++;
                    splice(@{$out_data}, $index, 0, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$out_index}", 'USER', "$out_line"]);
                    # ���[�U�o�͍�("output")�����[�U�o�͋敪�֐ݒ�
                    $obj->{user_out_kbn} = 'output';
                    # �o��pipe���̌������I��
                    last;
                }
            }
            # �Ώۃf�[�^�����o�������`�F�b�N
            if ($obj->{user_out_kbn} ne 'output') {
                #--------#
                # �����o #
                #--------#
                ${$out_index}++;
                if ($#{$out_data} < 0) {
                    #������������������#
                    # �o�͍σf�[�^�Ȃ� #
                    #������������������#
                    # �o��pipe���ɍs�f�[�^��ǉ�
                    push(@{$out_data}, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$out_index}", 'USER', "$out_line"]);
                } else {
                    #������������������������#
                    # �㑱�ɏo�͍σf�[�^���� #
                    #������������������������#
                    # �o��pipe���̐擪�ɍs�f�[�^��}��
                    splice(@{$out_data}, 0, 0, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$out_index}", 'USER', "$out_line"]);
                }
                # ���[�U�o�͍�("output")�����[�U�o�͋敪�֐ݒ�
                $obj->{user_out_kbn} = 'output';
            }
        }
    } elsif ($obj->{get_kbn} eq 'input') {
        #================================================#
        # ����pipe�����x�[�X�Ƀ��[�U��s�o�͏��֏o�� #
        #================================================#
        # �J�����g�̓���pipe���(�s���)���擾
        my $get_data = \@{${$in_data}[$obj->{get_index}]};
        # �s�f�[�^�����[�U��s�o�͏��̍Ō�ɒǉ�
        push(@{$mid_data}, ["${$get_data}[0]", "${$get_data}[1]", "${$get_data}[2]", 'USER', "$out_line"]);
    } else {
        #==================================================#
        # �I���W�i�������x�[�X�Ƀ��[�U��s�o�͏��֏o�� #
        #==================================================#
        # �s���(get�s���(�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ��A"USER"�A�s�f�[�^)�����[�U��s�o�͏��̍Ō�ɒǉ�
        push(@{$mid_data}, ["${$obj->{get_num}}[0]", "${$obj->{get_num}}[1]", "${$obj->{get_num}}[2]", 'USER', "$out_line"]);
    }
}
###################################################################################################
#   ���� ���o�f�[�^�폜 ����                                                                      #
###################################################################################################
sub del_data {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    # ���� �F ���o�f�[�^����J�����g�s�iseek���Ă���ꍇ�́A���̍s�j���폜                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my ($obj)      = @_;                                                                      # �I�u�W�F�N�g
    my $cond_index = $obj->{cond_index};                                                      # �����ʒu
    my $in_data    = \@{${$obj->{pipe_data}}[$cond_index]};                                   # (�����ʒu��)����pipe���
    my $buff_data  = \@{${$obj->{buff_data}}[$cond_index]};                                   # (�����ʒu��)�o�b�t�@���
    my $mid_data   = \@{${$obj->{mid_data}}[$cond_index]};                                    # (�����ʒu��)���[�U��s�o�͏��
    my $out_data   = \@{${$obj->{pipe_data}}[($cond_index + 1)]};                             # (�����ʒu��)�o��pipe���
    my $out_index  = \${$obj->{out_index}}[$cond_index];                                      # (�����ʒu��)�o�͌���
    
    # get�敪���`�F�b�N���A�폜��𔻒f
    if ($obj->{get_kbn} eq 'buff') {
        ######################
        # �o�b�t�@�����폜 #
        ######################
        # �J�����g���ŏI�o�b�t�@���ʒu�������ꍇ�A�폜�f�[�^(�o�͋敪="DEL")���o�b�t�@���̍Ō�֒ǉ�
        if ($obj->{get_index} == $#{$buff_data}) {
            #================================#
            # �J�����g���ŏI�o�b�t�@���ʒu #
            #================================#
            # �o�b�t�@���̍Ō�ɍ폜�f�[�^��ǉ�
            push(@{$out_data}, ["${${$buff_data}[$#{$buff_data}]}[0]", '', '', 'DEL', '']);
        } else {
            #====================#
            # �J�����g�������ύs #
            #====================#
            # �o��pipe��������
            my $del_flg = '';                                                                 # �폜�t���O�i�P���Y���s�ԍ����o�j
            for (my $index=$#{$out_data} ; $index >= 0 ; $index--) {
                # �폜�Ώۍs���`�F�b�N
                if (${${$out_data}[$index]}[2] == ${$obj->{get_num}}[2]) {
                    #------------------#
                    # ���͍s�ԍ�����v #
                    #------------------#
                    # ��^���o�ɂ��o�͂��`�F�b�N
                    if (${${$out_data}[$index]}[4] eq '' or $index == 0) {
                        #��������������#
                        # ��^���o�o�� #
                        #��������������#
                        # �Y���f�[�^���폜
                        splice(@{$out_data}, $index, 1);
                        # �o��pipe���̌������I��
                        last;
                    } else {
                        #����������������#
                        # ���[�U���o�o�� #
                        #����������������#
                        # �Y���s�ԍ����o("1")���폜�t���O�ɐݒ�
                        $del_flg = '1';
                    }
                # �폜�t���O���Y���s�ԍ����o("1")�̏ꍇ�A�Y���f�[�^���폜
                } elsif ($del_flg eq '1') {
                    #--------------------#
                    # ���Y���s�ԍ����o�� #
                    #--------------------#
                    splice(@{$out_data}, ($index + 1), 1);
                    # �o��pipe���̌������I��
                    last;
                }
            }
        }
        # ���[�U�o�͍�("output")�����[�U�o�͋敪�֐ݒ�
        $obj->{user_out_kbn} = 'output';
    } elsif ($obj->{get_kbn} eq 'input') {
        ######################
        # ����pipe�����폜 #
        ######################
        # �J�����g�s�̍폜�w�������[�U��s�o�͏��̍Ō�ɒǉ�
        my $get_data = \@{${$in_data}[$obj->{get_index}]};
        push(@{$mid_data}, ["${$get_data}[0]", '', "${$get_data}[2]", 'DEL', '']);
    } else {
        #========================================#
        # �I���W�i�����ɊY������s�f�[�^���폜 #
        #========================================#
        # �s���(get�s���(�I���W�i���s�ԍ��A""�A���͍s�ԍ����)�̍폜�w�������[�U��s�o�͏��̍Ō�ɒǉ�
        push(@{$mid_data}, ["${$obj->{get_num}}[0]", '', "${$obj->{get_num}}[2]", 'DEL', '']);
    }
}
###################################################################################################
#   ���� �s�����s�R�[�h�폜 ����                                                                  #
###################################################################################################
sub cut_last_0a{
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0] = �I�u�W�F�N�g                                                            #
    #         $_[1] = �s�f�[�^                                                                #
    # ���� �F �s���̉��s�R�[�h���폜                                                          #
    # �ԋp �F �s�f�[�^                                                                        #
    #-----------------------------------------------------------------------------------------#
    if ((substr $_[0], -1) eq "\n") {
        chop $_[0];
    }
}
###################################################################################################
#   ���� ���K�\���w��ɂ��s���o�̋N�_(�J�n����)���o ����                                        #
###################################################################################################
sub get_cond_lr_s {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #      �F $_[1]  = �J�����g�s�ԍ�                                                         #
    #      �F $_[2]  = �ŏI�s�ԍ�                                                             #
    #      �F $_[3]  = �s�f�[�^                                                               #
    #      �F $_[4�`]= ���o�����i���K�\���ɂ��s���o�j                                       #
    # ���� �F �I�������Ȃ��j                                                                  #
    #                  �E�s�ԍ��w��i���o�敪��"L"�j�ɕϊ�                                    #
    #         �I����������j                                                                  #
    #                  �E�I�����������K�\���̏ꍇ�A�J�n�̂ݍs�ԍ��w��i���o�敪��"r"�j�ɕϊ�  #
    #                  �E��L�ȊO�̏ꍇ�A�s�ԍ��w��i���o�敪��"L"�j�ɕϊ�                    #
    # �ԋp �F �ϊ��㒊�o�����i�s�ԍ��w��ɕϊ��������o�����j                                  #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj       = shift;                                                                    # �I�u�W�F�N�g
    my $line_now  = shift;                                                                    # �J�����g�s�ԍ�
    my $line_end  = shift;                                                                    # �ŏI�s�ԍ�
    my $line_data = shift;                                                                    # �s�f�[�^
    my @add_cond  = ();                                                                       # �ϊ��㒊�o����
    my $in_data   = \@{${$obj->{pipe_data}}[$obj->{cond_index}]};                             # (�����ʒu��)����pipe���
    
    ##################################
    # ���K�\���w����s�ԍ��w��ɕϊ� #
    ##################################
    foreach my $cond(@_) {
        #********************************************************************************#
        # �����o�����̏ڍׁ�                                                             #
        # ${$cond}[0] �F "LR"(���K�s���ɂ��s���o)                                      #
        # ${$cond}[1] �F �m��ے�敪                                                    #
        # ${$cond}[2] �F �J�n����(���o����/�J�n����)                                     #
        # ${$cond}[3] �F[�I������({+|-}�͈�/end[-�͈�]/�I������)]                        #
        #     �F                   �F                                                    #
        # ${$cond}[8] �F �ے蒊�o�敪�inull���o�͑ΏۊO�A"0"���������o�A"1"���o�͑Ώہj  #
        # ${$cond}[9] �F �b��ے蒊�o�J�n�s                                              #
        #********************************************************************************#
        # ���o�����o�̓t���O��������
        my $cond_flg = '';                                                                   # ���o�����o�̓t���O�i"1"���ϊ��㒊�o�����o�͍ρj
        # �s�f�[�^(�J�����g�s)�ɊJ�n�������܂܂�Ă��邩�`�F�b�N
        if ("$line_data" =~ /${$cond}[2]/) {
            #==============#
            # �J�n�������� #
            #==============#
            # �m��ے肩�`�F�b�N
            if (${$cond}[1] eq '') {
                #------#
                # �m�� #
                #------#
                # ���I�������`�F�b�N��
                if (${$cond}[3] eq '') {
                    #��������������#
                    # �I�������Ȃ� #
                    #��������������#
                    # �s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                    push(@add_cond, ['L', '', "$line_now", "$line_now", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                } elsif (${$cond}[3] =~ /^end(-\d+)*$/ ) {
                    #�����������������������������#
                    # �ŏI�s����͈͎̔w��("end") #
                    #�����������������������������#
                    # �s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                    my $cond3 = $1;
                    if ($cond3 eq '') {
                        if ($line_end > 0) {
                            push(@add_cond, ['L', '', "$line_now", "$line_end", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                        } else {
                            push(@add_cond, ['L', '', "$line_now", "${$cond}[3]", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                        }
                    } else {
                        if ($line_end > 0) {
                            push(@add_cond, ['L', '', "$line_now", ($line_end + $cond3), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                        } else {
                            push(@add_cond, ['L', '', "$line_now", "${$cond}[3]", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                        }
                    }
                } elsif (${$cond}[3] =~ /^\+\d+$/ ) {
                    #������������������������������#
                    # �㑱�͈͎w��(�v���X�t������) #
                    #������������������������������#
                    # �s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                    push(@add_cond, ['L', '', "$line_now", ($line_now + ${$cond}[3]), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                } elsif (${$cond}[3] =~ /^-\d+$/ ) {
                    #��������������������������������#
                    # ��s�͈͎w��(�}�C�i�X�t������) #
                    #��������������������������������#
                    # �����Ȃ�
                } else {
                    #��������������#
                    # ���K�\���w�� #
                    #��������������#
                    # �J�n�̂ݍs�ԍ��w��("r")��ϊ��㒊�o�����֒ǉ�
                    push(@add_cond, ['r', '', "$line_now", "${$cond}[3]", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                }
            } else {
                #------#
                # �ے� #
                #------#
                # ���I�������`�F�b�N��
                if (${$cond}[3] eq '') {
                    #��������������#
                    # �I�������Ȃ� #
                    #��������������#
                    # �ے蒊�o�o�͑Ώۂ̏ꍇ�A�s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                    if (${$cond}[8] eq '1') {
                        push(@add_cond, ['L', '', "${$cond}[9]", ($line_now - 1), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                    }
                    ${$cond}[9] = $line_now + 1;
                } elsif (${$cond}[3] =~ /^end(-\d+)*$/ ) {
                    #�����������������������������#
                    # �ŏI�s����͈͎̔w��("end") #
                    #�����������������������������#
                    my $cond3 = $1;
                    if (${$cond}[8] eq '1') {
                        push(@add_cond, ['L', '', "${$cond}[9]", ($line_now - 1), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                    }
                    ${$cond}[9] = $line_end + 1;
                    if ($cond3 ne '') {
                        ${$cond}[9] += $cond3;
                    }
                } elsif (${$cond}[3] =~ /^\+\d+$/ ) {
                    #������������������������������#
                    # �㑱�͈͎w��(�v���X�t������) #
                    #������������������������������#
                    # �ے蒊�o�o�͑Ώۂ̏ꍇ�A�s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                    if (${$cond}[8] eq '1') {
                        push(@add_cond, ['L', '', "${$cond}[9]", ($line_now - 1), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                    }
                    ${$cond}[9] = $line_now + ${$cond}[3] + 1;
                } elsif (${$cond}[3] =~ /^-\d+$/ ) {
                    #��������������������������������#
                    # ��s�͈͎w��(�}�C�i�X�t������) #
                    #��������������������������������#
                    # �����Ȃ�
                } else {
                    #��������������#
                    # ���K�\���w�� #
                    #��������������#
                    # �ے蒊�o�o�͑Ώۂ̏ꍇ�A�J�n�̂ݍs�ԍ��w��("r")��ϊ��㒊�o�����֒ǉ�
                    if (${$cond}[8] eq '1') {
                        push(@add_cond, ['L', '', "${$cond}[9]", ($line_now - 1), "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                    }
                }
                # �ے蒊�o�敪��������
                ${$cond}[8] = '';
            }
            # �ϊ��㒊�o�����o�͍�("1")�𒊏o�����o�̓t���O�֐ݒ�
            $cond_flg = '1';
        }
        # �I���������}�C�i�X�t�������������ꍇ�A��s�s�ɊJ�n�������܂܂�Ă��邩�`�F�b�N
        if (${$cond}[3] =~ /^-\d+$/ and ${$in_data}[(${$cond}[3] * -1)] ne 'Data_Extraction_END' and ${${$in_data}[(${$cond}[3] * -1)]}[4] =~ /${$cond}[2]/) {
            # �m��ے肩�`�F�b�N
            if (${$cond}[1] eq '') {
                #------#
                # �m�� #
                #------#
                # �s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                my $cond_end   = $line_now + (${$cond}[3] * -1) + 1;
                my $cond_start = $cond_end + ${$cond}[3];
                push(@add_cond, ['L', '', "$cond_start", "$cond_end", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
            } else {
                #------#
                # �ے� #
                #------#
                # �ے蒊�o�o�͑Ώۂ̏ꍇ�A�s�ԍ��w�蒊�o("L")��ϊ��㒊�o�����֒ǉ�
                if (${$cond}[8] eq '1') {
                    push(@add_cond, ['L', '', "${$cond}[9]", "$line_now", "${$cond}[4]", "${$cond}[5]", "${$cond}[6]", "${$cond}[7]"]);
                }
                # �b��ے蒊�o�J�n�s���Đݒ�
                ${$cond}[9] = ($line_now + (${$cond}[3] * -1) + 2);
                # �ے蒊�o�敪��������
                ${$cond}[8] = '';
            }
            # �ϊ��㒊�o�����o�͍�("1")�𒊏o�����o�̓t���O�֐ݒ�
            $cond_flg = '1';
        }
        # �ϊ��㒊�o���������o�͂��`�F�b�N
        if ($cond_flg eq '') {
            #========#
            # ���o�� #
            #========#
            # ���o�����̏�Ԃ��`�F�b�N���A�ے蒊�o�敪�Ǝb��ے蒊�o�J�n�s��ݒ�
            if (${$cond}[8] eq '') {
                #------------#
                # �o�͑ΏۊO #
                #------------#
                if (${$cond}[3] eq '' or ${$cond}[3] =~ /^[\+-]\d+$/ or ${$cond}[3] =~ /^end(-\d+)*$/) {
                    #������������������������������������������������������������������������#
                    # �I�����������A���̓v���X�}�C�i�X�t�������w��A���͍ŏI�s����͈͎̔w�� #
                    #������������������������������������������������������������������������#
                    # �b��ے蒊�o�J�n�s���J�����g�s�ȑO���w���ꍇ�A�o�͑Ώ�("1")��ے蒊�o�敪�ɐݒ�
                    if (${$cond}[9] <= $line_now) {
                        ${$cond}[8] = '1';
                    }
                } else {
                    #��������������#
                    # ���K�\���w�� #
                    #��������������#
                    # �I���������s�f�[�^�ɑ��݂���ꍇ�A�ے蒊�o�敪�Ǝb��ے蒊�o�J�n�s��ݒ�
                    if ($line_data =~ /${$cond}[3]/) {
                        # �������o("0")��ے蒊�o�敪�֐ݒ�
                        ${$cond}[8] = '0';
                        # ���s�̍s�ԍ����b��ے蒊�o�J�n�s�֐ݒ�
                        ${$cond}[9] = ($line_now + 1);
                    }
                }
            } elsif (${$cond}[8] eq '0') {
                #----------#
                # �������o #
                #----------#
                ${$cond}[8] = '1';
                ${$cond}[9] = $line_now;
            }
        }
    }
    
    ########################
    # �ϊ��㒊�o������ԋp #
    ########################
    return @add_cond;
}
###################################################################################################
#   ���� ���K�\���w��ɂ��s���o�͈̔�(�I������)���o ����                                        #
###################################################################################################
sub get_cond_lr_e {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �J�����g�s�ԍ�                                                         #
    #      �F $_[1�`]= ���o����                                                               #
    # ���� �F ���K�\���i�I�������j���s�ԍ��w��ɕϊ�                                          #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $line_now = shift;                                                                     # �J�����g�s�ԍ�
    
    ##################################
    # ���K�\���w����s�ԍ��w��ɕϊ� #
    ##################################
    foreach my $cond(@_) {
        ${$cond}[0] = 'L';
        ${$cond}[3] = $line_now;
    }
}
###################################################################################################
#   ���� �ŏI�s�w��ɂ��s���o�̋N�_(���o�J�n����)���o ����                                      #
###################################################################################################
sub get_cond_l_s {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �ŏI�s�ԍ�                                                             #
    #      �F $_[1�`]= ���o�����i�ŏI�s�w��"E"�ɂ��s���o�j                                  #
    # ���� �F �ŏI�s�w����s�ԍ��w��ɕϊ�                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $line_end = shift;                                                                     # �ŏI�s�ԍ�
    
    ################################
    # �ŏI�s�w����s�ԍ��w��ɕϊ� #
    ################################
    foreach my $cond(@_) {
        #********************************************************************************#
        # �����o�����̏ڍׁ�                                                             #
        # ${$cond}[0] �F "L"(�s�ԍ��ɂ��s���o)                                         #
        # ${$cond}[1] �F �m��ے�敪                                                    #
        # ${$cond}[2] �F "end"(�ŏI�s�w��)                                               #
        # ${$cond}[3] �F[�I������(�v���X�}�C�i�X�͈�/E/�I���s�ԍ�)]                      #
        #********************************************************************************#
        # �J�n�s�ԍ����Z�o
        if (${$cond}[2] =~ /^end(-\d+)$/) {
            ${$cond}[2] = $line_end + $1;
        } else {
            ${$cond}[2] = $line_end;
        }
        # ���o�I���������`�F�b�N���A�I���s�ԍ���ݒ�
        if (${$cond}[3] eq '') {
            #==========#
            # �w��Ȃ� #
            #==========#
            # �ŏI�s�ԍ����I���s�ԍ��֐ݒ�
            ${$cond}[3] = ${$cond}[2];
        } elsif (${$cond}[3] =~ /^end(-\d+)*$/) {
            #=============================#
            # �ŏI�s����͈͎̔w��("end") #
            #=============================#
            # �I���s�ԍ����Z�o
            my $cond3 = $1;
            ${$cond}[3] = $line_end;
            if ($cond3 ne '') {
                ${$cond}[3] += $cond3;
            }
            # �J�n�s�ԍ����I���s�ԍ����������ꍇ�A���ւ���
            if (${$cond}[2] > ${$cond}[3]) {
                my $temp_su = ${$cond}[2];
                ${$cond}[2] = ${$cond}[3];
                ${$cond}[3] = $temp_su;
            }
        } elsif (${$cond}[3] =~ /^\d+$/) {
            #============#
            # �s�ԍ��w�� #
            #============#
            # �J�n�s�ԍ����I���s�ԍ����������ꍇ�A���ւ���
            if (${$cond}[2] > ${$cond}[3]) {
                my $temp_su = ${$cond}[2];
                ${$cond}[2] = ${$cond}[3];
                ${$cond}[3] = $temp_su;
            }
        } elsif (${$cond}[3] =~ /^\+\d+$/) {
            #------------------------------#
            # �㑱�͈͎w��(�v���X�t������) #
            #------------------------------#
            # �I���s�ԍ����Z�o
            ${$cond}[3] += ${$cond}[2];
        } elsif (${$cond}[3] =~ /^-\d+$/) {
            #--------------------------------#
            # ��s�͈͎w��(�}�C�i�X�t������) #
            #--------------------------------#
            # �J�n�s�ԍ��ƏI���s�ԍ����Z�o
            my $temp_su  = ${$cond}[2];
            ${$cond}[2] += ${$cond}[3];
            ${$cond}[3]  = $temp_su;
        }
    }
}
###################################################################################################
#   ���� �ŏI�s�w��ɂ��s���o�͈̔�(���o�I������)���o ����                                      #
###################################################################################################
sub get_cond_l_e {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �ŏI�s�ԍ�                                                             #
    #      �F $_[1�`]= ���o�����i�ŏI�s�w��"end"�ɂ��s���o�j                                #
    # ���� �F �ŏI�s�w����s�ԍ��w��ɕϊ�                                                    #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $line_end = shift;                                                                     # �ŏI�s�ԍ�
    
    ################################
    # �ŏI�s�w����s�ԍ��w��ɕϊ� #
    ################################
    foreach my $cond(@_) {
        #********************************************************************************#
        # �����o�����̏ڍׁ�                                                             #
        # ${$cond}[0] �F "L"(�s�ԍ��ɂ��s���o)                                         #
        #     �F                   �F                                                    #
        # ${$cond}[3] �F "end"(�ŏI�s�w��)                                               #
        #********************************************************************************#
        if (${$cond}[3] =~ /^end(-\d+)$/) {
            ${$cond}[3] = $line_end + $1;
        } else {
            ${$cond}[3] = $line_end;
        }
        # �J�n�s�ԍ����I���s�ԍ����������ꍇ�A���ւ���
        if (${$cond}[2] > ${$cond}[3]) {
            my $temp_su = ${$cond}[2];
            ${$cond}[2] = ${$cond}[3];
            ${$cond}[3] = $temp_su;
        }
    }
}
###################################################################################################
#   ���� ���[�U���o ����                                                                          #
###################################################################################################
sub get_cond_user {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �I�u�W�F�N�g                                                           #
    #      �F $_[1]  = �s�f�[�^                                                               #
    #      �F $_[1�`]= ���[�U�[����                                                           #
    # ���� �F ���[�U�֐��̌ďo��                                                              #
    # �ԋp �F ���[�U���o���ʁi���o�Ώۋ敪�j                                                  #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $obj              = shift;                                                             # �I�u�W�F�N�g
    my $line_data        = shift;                                                             # �s�f�[�^
    my $extraction_data  = undef;                                                             # ���[�U���o���ʁi���o�Ώۋ敪�j
    $obj->{user_out_kbn} = '';                                                                # ���[�U�o�͋敪
    my $buff_data        = \@{${$obj->{buff_data}}[$obj->{cond_index}]};                      # (�����ʒu��)�o�b�t�@���
    
    ##############
    # ���[�U���o #
    ##############
    foreach my $user(@_) {
        # ��seek���̐ݒ聄
        $obj->{seek_kbn}          = 'buff';                                                   # seek�敪���o�b�t�@���("buff")
        @{$obj->{seek_num}}[0..2] = @{${$buff_data}[$#{$buff_data}]};                         # seek�s��񁩃o�b�t�@���(�I���W�i���s�ԍ��A���R�[�hbyte�ʒu�A���͍s�ԍ�)
        $obj->{seek_index}        = $#{$buff_data};                                           # seek�ʒu���o�b�t�@���(�J�����g���ʒu)
        # ��get���̐ݒ聄
        $obj->{get_kbn}           = $obj->{seek_kbn};                                         # get�敪
        @{$obj->{get_num}}        = @{$obj->{seek_num}};                                      # get�s���
        $obj->{get_index}         = $obj->{seek_index};                                       # get�ʒu
        # �ŏI�o�b�t�@���̃��R�[�hbyte�ʒu�ֈړ�
        seek EXTRACTION_FILE, (${$obj->{get_num}}[1]), 0 or "$!($obj->{in_name})";
        
        #==================#
        # ���[�U�֐��ďo�� #
        #==================#
        # ���[�U�֐��ďo�����̍\������
        my $user_sub = '&'.${$user}[1].'('."\'$line_data\'";
        for (my $index1=2 ; $index1 <= $#{$user}; $index1++) {
            $user_sub .= ', "'.${$user}[$index1].'"';
        }
        $user_sub .= ');';
        # ���[�U�֐��̌ďo���A���ʎ擾
        $extraction_data = "$extraction_data" | eval($user_sub);
    }
    
    ########################################
    # ���[�U���o���ʁi���o�Ώۋ敪�j��ԋp #
    ########################################
    return "$extraction_data";
}
###################################################################################################
#   ���� �s�E�񒊏o ����                                                                          #
###################################################################################################
sub get_cond_lc {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�f�[�^                                                               #
    #      �F $_[1]  = �z�񉻂����s�f�[�^�̔z��                                             #
    #      �F $_[2�`]= ���o�����i�����s�̍s�E�u���b�N���o�j                                   #
    # ���� �F �s���o�A�񒊏o�i��ԍ��w��ɂ��񒊏o�A���K�\���w��ɂ��񒊏o�j              #
    # �ԋp �F ���o���ʁi���o�Ώۋ敪�j                                                        #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $line_data   = shift;                                                                  # �s�f�[�^
    my $line_col_su = shift;                                                                  # �z�񉻂����s�f�[�^�̔z��
    my $extraction_data = '';
    
    # �񒊏o�����̗L�����`�F�b�N
    if ((grep{${$_}[4] eq ''}@_) > 0) {
        #========#
        # �s���o #
        #========#
        $extraction_data = '1';
    } else {
        #========#
        # �񒊏o #
        #========#
        # ��ԍ��w��ɂ��񒊏o
        $extraction_data = &get_cond_c($line_col_su, grep{${$_}[4] eq 'C'}@_);
        # ���K�\���w��ɂ��񒊏o
        $extraction_data = "$extraction_data" | &get_cond_cr("$line_data", $line_col_su, grep{${$_}[4] eq 'CR'}@_);
    }
    
    # �񒊏o���ʂ�ԋp
    return "$extraction_data";
}
###################################################################################################
#   ���� ��ԍ��w��ɂ��񒊏o ����                                                              #
###################################################################################################
sub get_cond_c {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �z�񉻂����s�f�[�^�̔z��                                             #
    #      �F $_[1�`]= ���o�����i��ԍ��ɂ��񒊏o�j                                         #
    # ���� �F ��ԍ��w��ɂ��񒊏o                                                          #
    # �ԋp �F �񒊏o���ʁi���o�Ώۋ敪�j                                                      #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $col_su          = shift;                                                              # �z�񉻂����s�f�[�^�̔z��
    my $col_start       = undef;                                                              # (�񒊏o��)���o�J�n��
    my $col_end         = undef;                                                              # (�񒊏o��)���o�I����
    my $col_add         = undef;                                                              # (�񒊏o��)cond����ʒu
    my $extraction_data = '0' x $col_su;                                                      # �񒊏o���ʁi���o�Ώۋ敪�j
    
    ##########
    # �񒊏o #
    ##########
    foreach my $cond(@_) {
        #********************************************************************************#
        # �����o�����̏ڍׁ�                                                             #
        # �񒊏o���j                                                                     #
        # ${$cond}[0] �F "C"(��ԍ��ɂ��񒊏o)                                         #
        # ${$cond}[1] �F �m��ے�敪                                                    #
        # ${$cond}[2] �F �J�n����(��ԍ�/�J�n��ԍ�/end[-�s��])                          #
        # ${$cond}[3] �F[�I������({+|-}�͈�/end[-�s��]/�I����ԍ�)]                      #
        #     �F                   �F                                                    #
        # ------------------------------------------------------------------------------ #
        # �s�񒊏o���j                                                                   #
        #     �F                   �F                                                    #
        # ${$cond}[4] �F "C"(��ԍ��ɂ��񒊏o)                                         #
        # ${$cond}[5] �F �m��ے�敪                                                    #
        # ${$cond}[6] �F �J�n����(��ԍ�/�J�n��ԍ�/end[-�s��])                          #
        # ${$cond}[7] �F[�I������({+|-}�͈�/end[-�s��]/�I����ԍ�)]                      #
        #     �F                   �F                                                    #
        #********************************************************************************#
        #====================#
        # cond����ʒu�̐ݒ� #
        #====================#
        # ���o����Ώۂ��`�F�b�N���Acond����ʒu��ݒ�
        if (${$cond}[0] eq 'C') {
            #--------#
            # �񒊏o #
            #--------#
            $col_add = 0;
        } else {
            #----------#
            # �s�񒊏o #
            #----------#
            $col_add = 4;
        }
        
        #==================#
        # ���o�J�n���ݒ� #
        #==================#
        # �J�n�����̎w����@���`�F�b�N
        if (${$cond}[(2 + $col_add)] =~ /^end(-\d+)*$/) {
            #-----------------------------#
            # �ŏI�񂩂�͈͎̔w��("end") #
            #-----------------------------#
            my $cond2 = $1;
            $col_start = $col_su;
            if ($cond2 ne '') {
                $col_start += $cond2;
            }
        } else {
            #------------#
            # ��ԍ��w�� #
            #------------#
            $col_start = ${$cond}[(2 + $col_add)];
        }
        
        #==================#
        # ���o�I�����ݒ� #
        #==================#
        # �I�������̎w����@���`�F�b�N
        if (${$cond}[(3 + $col_add)] eq '') {
            #--------------#
            # �͈͎w��Ȃ� #
            #--------------#
            $col_end = $col_start;
        } elsif (${$cond}[(3 + $col_add)] =~ /^end(-\d+)*$/) {
            #-----------------------------#
            # �ŏI�񂩂�͈͎̔w��("end") #
            #-----------------------------#
            my $cond3 = $1;
            if ($cond3 eq '') {
                if ($col_start <= $col_su) {
                    $col_end = $col_su;
                } else {
                    $col_end   = $col_start;
                    $col_start = $col_su;
                }
            } else {
                if ($col_start <= ($col_su + $cond3)) {
                    $col_end = $col_su + $cond3;
                } else {
                    $col_end   = $col_start;
                    $col_start = $col_su + $cond3;
                }
            }
        } elsif (${$cond}[(3 + $col_add)] =~ /^\-(\d+)$/) {
            #--------------------------------#
            # ��s�͈͎w��(�}�C�i�X�t������) #
            #--------------------------------#
            $col_end   = $col_start;
            $col_start = $col_start + ${$cond}[(3 + $col_add)];
        } elsif (${$cond}[(3 + $col_add)] =~ /^\+(\d+)$/) {
            #------------------------------#
            # �㑱�͈͎w��(�v���X�t������) #
            #------------------------------#
            $col_end   = $col_start + ${$cond}[(3 + $col_add)];
        } elsif (${$cond}[(2 + $col_add)] <= ${$cond}[(3 + $col_add)]) {
            #----------------#
            # �㑱��ԍ��w�� #
            #----------------#
            $col_end   = ${$cond}[(3 + $col_add)];
        } else {
            #----------------#
            # ��s��ԍ��w�� #
            #----------------#
            $col_end   = $col_start;
            $col_start = ${$cond}[(3 + $col_add)];
        }
        
        #==================#
        # ���o�Ώۗ��ݒ� #
        #==================#
        if ($col_start < 0) {$col_start = 0}
        if ($col_end   < 0) {$col_end   = 0}
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            # �m��ے�敪�Ə����͈͂��`�F�b�N���A���o�Ώۗ��ݒ�
            if ((${$cond}[(1 + $col_add)] eq '' and $index2 >= $col_start and $index2 <= $col_end) or (${$cond}[(1 + $col_add)] ne '' and ($index2 < $col_start or $index2 > $col_end))) {
                substr($extraction_data, $index2, 1) = '1';
            }
        }
    }
    
    ####################
    # �񒊏o���ʂ�ԋp #
    ####################
    return "$extraction_data";
}
###################################################################################################
#   ���� ���K�\���w��ɂ��񒊏o ����                                                            #
###################################################################################################
sub get_cond_cr {
    #-----------------------------------------------------------------------------------------#
    # ���� �F $_[0]  = �s�f�[�^                                                               #
    #      �F $_[1]  = �z�񉻂����s�f�[�^�̔z��                                             #
    #      �F $_[1�`]= ���o�����i���K�\���ɂ��񒊏o�j                                       #
    # ���� �F ���K�\���w��ɂ��񒊏o                                                        #
    # �ԋp �F �񒊏o���ʁi���o�Ώۋ敪�j                                                      #
    #-----------------------------------------------------------------------------------------#
    ############
    # �ϐ���` #
    ############
    my $in_line         = shift;                                                              # �s�f�[�^
    my $col_su          = shift;                                                              # �z�񉻂����s�f�[�^�̔z��
    my $col_start       = undef;                                                              # (�񒊏o��)���o�J�n��
    my $col_end         = undef;                                                              # (�񒊏o��)���o�I����
    my $col_add         = undef;                                                              # (�񒊏o��)cond����ʒu
    my $check_key1      = undef;                                                              # (�񒊏o��)�J�n����L�[
    my $check_key2      = undef;                                                              # (�񒊏o��)�I������L�[
    my $extraction_data = '0' x $col_su;                                                      # �񒊏o���ʁi���o�Ώۋ敪�j
    
    ##########
    # �񒊏o #
    ##########
    foreach my $cond(@_) {
        #********************************************************************************#
        # �����o�����̏ڍׁ�                                                             #
        # �񒊏o���j                                                                     #
        # ${$cond}[0] �F "CR"(���K�s���ɂ��񒊏o)                                      #
        # ${$cond}[1] �F �m��ے�敪                                                    #
        # ${$cond}[2] �F �J�n����(���o����/�J�n����)                                     #
        # ${$cond}[3] �F[�I������({+|-}�͈�/end[-�͈�]/�I������)]                        #
        #     �F                   �F                                                    #
        # ------------------------------------------------------------------------------ #
        # �s�񒊏o���j                                                                   #
        #     �F                   �F                                                    #
        # ${$cond}[4] �F "CR"(���K�s���ɂ��񒊏o)                                      #
        # ${$cond}[5] �F �m��ے�敪                                                    #
        # ${$cond}[6] �F �J�n����(���o����/�J�n����)                                     #
        # ${$cond}[7] �F[�I������({+|-}�͈�/end[-�͈�]/�I������)]                        #
        #     �F                   �F                                                    #
        #********************************************************************************#
        #============================#
        # �񒊏o����p�s�f�[�^�̐ݒ� #
        #============================#
        # �s�f�[�^��񒊏o����p�s�f�[�^�֐ݒ�
        my $line_data = "$in_line";
        
        #====================#
        # cond����ʒu�̐ݒ� #
        #====================#
        # ���o����Ώۂ��`�F�b�N���Acond����ʒu��ݒ�
        if (${$cond}[0] eq 'CR') {
            #--------#
            # �񒊏o #
            #--------#
            $col_add = 0;
        } else {
            #----------#
            # �s�񒊏o #
            #----------#
            $col_add = 4;
        }
        
        #==========================#
        # �J�n�����E�I�������̕␳ #
        #==========================#
        # �������s�v�ƂȂ�L�q���폜
        ${$cond}[(2 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
        ${$cond}[(2 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
        ${$cond}[(2 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
        ${$cond}[(2 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
        if (${$cond}[(3 + $col_add)] ne '' and ${$cond}[(3 + $col_add)] !~ /^[\+-]\d+$/ and ${$cond}[(3 + $col_add)] !~ /^end(-\d+)*$/) {
            ${$cond}[(3 + $col_add)] =~  s/^\\s\*|^\\,\*|^,\*|^\[\\s\]\*|^\[\\,\]\*|^\[,\]\*|^\[\\,\\s\]\*|^\[,\\s\]\*|^\[\\s\\,\]\*|^\[\\s,\]\*//;
            ${$cond}[(3 + $col_add)] =~  s/^(\[.*)\\s(.*\]\*)/$1$2/;
            ${$cond}[(3 + $col_add)] =~  s/^(\[.*)\\,(.*\]\*)/$1$2/;
            ${$cond}[(3 + $col_add)] =~  s/^(\[.*),(.*\]\*)/$1$2/;
        }
        
        #==============#
        # �ϐ��������� #
        #==============#
        my @cond_c_new = ();                                                                  # �����͈�
        $col_start = 0;                                                                       # (�񒊏o��)�J�n�ʒu
        $col_end   = 0;                                                                       # (�񒊏o��)�I���ʒu
        
        #============#
        # �񒊏o���� #
        #============#
        # �񒊏o����������܂Œ��o�i�������[�v�j
        while (1) {
            #----------------#
            # �J�n�����̕␳ #
            #----------------#
            my $key = undef;
            # �J�n������񒊏o����p�s�f�[�^����擾
            if ("$line_data" =~ /(${$cond}[(2 + $col_add)])/) {
                $key = $1;
            }
            $check_key1 = '';
            # ���[����؂蕶���łȂ���΁A��؂蕶��(���K�\��)��ǉ�
            if ($key !~ /^\s|^\,/) {
                $check_key1 .= '[^\s\,]*';
            }
            $check_key1 .= ${$cond}[(2 + $col_add)];
            # �E�[����؂蕶���łȂ���΁A��؂蕶��(���K�\��)��ǉ�
            if ($key !~ /\s$|\,$|\n$|\$$/) {
                $check_key1 .= '[^\s\,\n]*';
            }
            
            #--------------------#
            # �J�n�������`�F�b�N #
            #--------------------#
            # �񒊏o����p�s�f�[�^���J�n�������܂�ł��邩�`�F�b�N
            if ("$line_data" !~ /($check_key1)(.*)/) {
                #��������������#
                # �J�n�����Ȃ� #
                #��������������#
                # �񒊏o���菈���̌J��Ԃ�(while)�𔲂���
                last;
            }
            
            #------------------------------#
            # ����`�F�b�N�Ώۃf�[�^��ޔ� #
            #------------------------------#
            my $next_data = $2;
            
            #----------------#
            # �I�������̕␳ #
            #----------------#
            $check_key2 = '';
            # ���K�\���w��̏I�����������邩�`�F�b�N
            if (${$cond}[(3 + $col_add)] ne '' and ${$cond}[(3 + $col_add)] !~ /^[\+-]\d+$/ and ${$cond}[(3 + $col_add)] !~ /^end(-\d+)*$/) {
                #����������������������������#
                # ���K�\���w��̏I���������� #
                #����������������������������#
                # �I��������񒊏o����p�s�f�[�^����擾
                if ("$line_data" =~ /(${$cond}[(3 + $col_add)])/) {
                    $key = $1;
                }
                # ���[����؂蕶���łȂ���΁A��؂蕶��(���K�\��)��ǉ�
                if ($key !~ /^\s|^\,/) {
                    $check_key2 .= '[^\s\,]*';
                }
                $check_key2 .= ${$cond}[(3 + $col_add)];
                # �E�[����؂蕶���łȂ���΁A��؂蕶��(���K�\��)��ǉ�
                if ($key !~ /\s$|\,$|\n$|\$$/) {
                    $check_key2 .= '[^\s\,]*';
                }
            }
            
            #------------------#
            # ���o�J�n���ݒ� #
            #------------------#
            my @split_out1 = split /($check_key1)/, $line_data, 3;
            my $split_out1_add = 0;
            if ($split_out1[0] =~ /^\s+\,*\s*$|^\,+\s*$/) {
            } else {
                if ($split_out1[0] =~ /^\s|^\,/ and $split_out1[0] =~ /\s+$|\,+$/) {
                    $split_out1_add--;
                }
            }
            $col_start += (&get_col_data("$split_out1[0]")) + $split_out1_add + 1;
            
            #--------------------------#
            # ����`�F�b�N�J�n����Z�o #
            #--------------------------#
            my $col_split_out1 = &get_col_data("$split_out1[1]");
            my $col_end2 = $col_start + $col_split_out1 - 1;
            
            #------------------#
            # ���o�I�����ݒ� #
            #------------------#
            # �I�������̎w����@���`�F�b�N
            if (${$cond}[(3 + $col_add)] eq '') {
                #��������������#
                # �͈͎w��Ȃ� #
                #��������������#
                $col_end = $col_end2;
            } elsif (${$cond}[(3 + $col_add)] =~ /^end(-\d+)*$/) {
                #-----------------------------#
                # �ŏI�񂩂�͈͎̔w��("end") #
                #-----------------------------#
                my $cond3 = $1;
                if ($cond3 eq '') {
                    if ($col_start <= $col_su) {
                        $col_end = $col_su;
                    } else {
                        $col_end   = $col_start;
                        $col_start = $col_su;
                    }
                } else {
                    if ($col_start <= ($col_su + $cond3)) {
                        $col_end = $col_su + $cond3;
                    } else {
                        $col_end   = $col_start;
                        $col_start = $col_su + $cond3;
                    }
                }
            } elsif (${$cond}[(3 + $col_add)] =~ /^\+(\d+)$/) {
                #������������������������������#
                # �㑱�͈͎w��(�v���X�t������) #
                #������������������������������#
                $col_end = $col_end2 + ${$cond}[(3 + $col_add)];
            } elsif (${$cond}[(3 + $col_add)] =~ /^-(\d+)$/) {
                #��������������������������������#
                # ��s�͈͎w��(�}�C�i�X�t������) #
                #��������������������������������#
                $col_start += ${$cond}[(3 + $col_add)];
                $col_end    = $col_end2;
            } else {
                #������������#
                # ���K�\�w�� #
                #������������#
                if ("$next_data" =~ /($check_key2)(.*)/) {
                    my $back_data = $2;
                    my @split_out2 = split /($check_key2)/, $next_data, 3;
                    $col_end = $col_su - (&get_col_data("$back_data")) + 1;
                } else {
                    $col_end = $col_su;
                    my @split_out2 = &get_col_data("$line_data");
                    for (my $index4=($col_start - 1); $index4 <= ($col_end2 - 1); $index4++) {
                        if ("$split_out2[$index4]" =~ /($check_key2)/) {
                            $col_end = $col_end2;
                        }
                    }
                }
            }
            
            #----------------#
            # �����͈͂�ݒ� #
            #----------------#
            if ($col_start < 0) {$col_start = 0}
            if ($col_end   < 0) {$col_end   = 0}
            # ���o�J�n�񂩂璊�o�I���񂪎�����ɑ΂��ă`�F�b�N
            for (my $index3=$col_start; $index3 <= $col_end; $index3++) {
                # �����͈͓�("1")��ݒ�
                $cond_c_new[$index3] = '1';
            }
            
            #------------------------#
            # ����`�F�b�N����ݒ� #
            #------------------------#
            $col_start = $col_end2;                                                           # (�񒊏o��)�J�n�ʒu
            $line_data = "$next_data";                                                        # �񒊏o����p�s�f�[�^
        }
        
        #==================#
        # ���o�Ώۗ��ݒ� #
        #==================#
        for (my $index2=1; $index2 <= $col_su; $index2++) {
            # �m��ے�敪�Ə����͈͂��`�F�b�N���A���o�Ώۗ��ݒ�
            if ((${$cond}[(1 + $col_add)] eq '' and $cond_c_new[$index2] eq '1') or (${$cond}[(1 + $col_add)] ne '' and $cond_c_new[$index2] eq '')) {
                substr($extraction_data, $index2, 1) = '1';
            }
        }
    }
    
    ####################
    # �񒊏o���ʂ�ԋp #
    ####################
    return "$extraction_data";
}
1;